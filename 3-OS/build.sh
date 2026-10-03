nasm boot.asm -o boot.bin
nasm kernel.asm -o kernel.bin
# Create blank sectors
dd if=/dev/zero of=sector2.bin bs=512 count=1
dd if=/dev/zero of=sector3.bin bs=512 count=1

# Copy your text into sector 2
dd if=test.txt of=sector2.bin conv=notrunc

# Combine all 4 sectors: bootloader + kernel + sector 2 + sector 3 (writable target)
cat boot.bin kernel.bin sector2.bin sector3.bin > os.bin
qemu-system-x86_64 -drive format=raw,file=os.bin