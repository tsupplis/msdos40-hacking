"""Host-side oracle for the file-offset workload on check_dir32's FAT16 fixture."""
import struct
import subprocess


def verify_file32(folder, disk, mode, run_guest, fat, fat_length, directory, data_start, seed_size):
    sector = 512
    cluster_size = 1024
    boundary = 32 * 1024 * 1024
    saved = folder / "file32.img"

    def snapshot():
        saved.unlink(missing_ok=True)
        subprocess.run(["pce-img", "convert", "-q", "-O", "img", disk, saved], check=True)
        return saved.read_bytes()

    initial = snapshot()
    entry = next(p for p in range(directory, data_start, 32) if initial[p:p+11] == b"PAD     BIN")
    if struct.unpack_from("<HI", initial, entry+26) != (2, seed_size):
        raise RuntimeError("unexpected seed file")
    contents = bytearray(initial[data_start:data_start+seed_size])
    directories = initial[data_start+seed_size:data_start+seed_size+3*cluster_size]
    # Directory creation allocated the next three clusters. Extending PAD.BIN
    # must skip them. Each subsequent verify also checks for orphan allocations.
    base_fat = bytearray(initial[fat:fat+fat_length])
    seed_clusters = seed_size // cluster_size
    for action in ("b", "w", "a", "r", "t", "d"):
        if action == "b":
            contents.extend(b"Z" * (boundary-1025-seed_size))
        elif action == "w":
            contents.extend(b"Z"*1008 + b"0123456789abcdefg")
        elif action == "a":
            contents.extend(b"after-boundary")
            contents[boundary-2:boundary+2] = b"WXYZ"
        elif action == "t":
            del contents[boundary-1025:]
        elif action == "d":
            contents.clear()
        run_guest(action)
        data = snapshot()
        size = len(contents)
        if action == "d":
            if data[entry] != 0xe5:
                raise RuntimeError("PAD.BIN was not deleted")
        elif struct.unpack_from("<HI", data, entry+26) != (2, size):
            first, actual = struct.unpack_from("<HI", data, entry+26)
            raise RuntimeError(f"{action}: cluster {first}, size {actual}; expected cluster 2, size {size}")
        count = (size+cluster_size-1)//cluster_size
        expected_fat = base_fat.copy()
        for cluster in range(2, seed_clusters+2):
            struct.pack_into("<H", expected_fat, cluster*2, 0)
        cluster = 2
        visited = set()
        for index in range(count):
            if cluster in visited or not 2 <= cluster < (len(data)-data_start)//cluster_size+2:
                raise RuntimeError(f"{action}: invalid FAT chain at cluster {cluster}")
            if seed_clusters+2 <= cluster < seed_clusters+5:
                raise RuntimeError(f"{action}: file overlaps a directory")
            visited.add(cluster)
            offset = data_start+(cluster-2)*cluster_size
            chunk = contents[index*cluster_size:min((index+1)*cluster_size,size)]
            if data[offset:offset+len(chunk)] != chunk:
                raise RuntimeError(f"{action}: contents differ at file cluster {index}")
            successor, = struct.unpack_from("<H", data, fat+2*cluster)
            if index == count-1 and successor < 0xfff8:
                raise RuntimeError(f"{action}: missing end-of-chain")
            struct.pack_into("<H", expected_fat, 2*cluster, successor)
            cluster = successor
        if any(data[start:start+fat_length] != expected_fat for start in (fat, fat+fat_length)):
            raise RuntimeError(f"{action}: FAT mismatch or leaked allocation")
        guard = data_start+seed_size
        if (initial[:fat] != data[:fat] or directories != data[guard:guard+len(directories)]
                or initial[directory:entry] != data[directory:entry]
                or initial[entry+32:data_start] != data[entry+32:data_start]):
            raise RuntimeError(f"{action}: neighboring metadata or directories changed")
    print(f"PASS {mode}: file write, reboot read, truncate and delete at 32 MiB", flush=True)
