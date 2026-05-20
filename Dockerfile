FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget \
    curl \
    net-tools \
    unzip \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Create working directories
RUN mkdir -p /data /iso /novnc

# Setup noVNC
RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# 🚀 Optimized Premium Windows 11 Lite ISO (Tiny11 / SuperLite Edition)
ENV ISO_URL="https://archive.org/download/tiny11-2311/tiny11%202311%20x64.iso"

# Startup script (100% English & Dynamic Hardware Scaling for Win11)
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Parsing Runtime Environment Variables with Fallback Defaults\n\
if [ -e /dev/kvm ]; then\n\
  echo "✅ KVM acceleration available"\n\
  KVM_ARG="-enable-kvm"\n\
  CPU_ARG="host"\n\
  VM_RAM="${RAM:-4096}"        # Default to 4GB if not specified\n\
  VM_CORES="${CORES:-4}"       # Default to 4 Cores if not specified\n\
fi\n\
\n\
VM_DISK_SIZE="${DISK_SIZE:-50G}" # Default to 50GB if not specified\n\
\n\
# Download ISO if needed\n\
if [ ! -f "/iso/os.iso" ]; then\n\
  echo "📥 Downloading Windows 11 Lite ISO..."\n\
  wget -q --show-progress "$ISO_URL" -O "/iso/os.iso"\n\
fi\n\
\n\
# Create or Resize disk image dynamically\n\
if [ ! -f "/data/disk.qcow2" ]; then\n\
  echo "💽 Creating dynamic ${VM_DISK_SIZE} virtual disk..."\n\
  qemu-img create -f qcow2 "/data/disk.qcow2" "${VM_DISK_SIZE}"\n\
else\n\
  echo "💾 Existing virtual disk detected! Scaling target size to ${VM_DISK_SIZE}..."\n\
  qemu-img resize "/data/disk.qcow2" "${VM_DISK_SIZE}" > /dev/null 2>&1 || true\n\
fi\n\
\n\
# Windows-specific boot parameters\n\
BOOT_ORDER="-boot order=c,menu=on"\n\
if [ ! -s "/data/disk.qcow2" ] || [ $(stat -c%s "/data/disk.qcow2") -lt 1048576 ]; then\n\
  echo "🚀 First boot - installing Windows 11 from ISO"\n\
  BOOT_ORDER="-boot order=d,menu=on"\n\
fi\n\
\n\
echo "========================================================================="\n\
echo "⚙️ Booting Windows 11 Lite VM Profile:"\n\
echo "   -> Allocated RAM   : ${VM_RAM}MB / GB"\n\
echo "   -> Allocated Cores : ${VM_CORES} CPU(s)"\n\
echo "   -> Virtual Disk    : ${VM_DISK_SIZE}"\n\
echo "========================================================================="\n\
\n\
# Start QEMU with Windows 11 optimized dynamically injected settings\n\
qemu-system-x86_64 \\\n\
  $KVM_ARG \\\n\
  -machine q35,accel=kvm:tcg \\\n\
  -cpu $CPU_ARG \\\n\
  -m $VM_RAM \\\n\
  -smp $VM_CORES \\\n\
  -vga std \\\n\
  -usb -device usb-tablet \\\n\
  $BOOT_ORDER \\\n\
  -drive file=/data/disk.qcow2,format=qcow2 \\\n\
  -drive file=/iso/os.iso,media=cdrom \\\n\
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \\\n\
  -device e1000,netdev=net0 \\\n\
  -display vnc=:0 \\\n\
  -name "Windows11_VM" &\n\
\n\
# Start noVNC Silently\n\
sleep 5\n\
websockify --web /novnc 6080 localhost:5900 >/dev/null 2>&1 &\n\
\n\
echo "===================================================="\n\
echo "🌐 Connect via VNC: http://localhost:6080"\n\
echo "🔌 After install, use RDP: localhost:3389"\n\
echo "===================================================="\n\
\n\
tail -f /dev/null\n' > /start.sh && chmod +x /start.sh

VOLUME ["/data", "/iso"]
EXPOSE 6080 3389
CMD ["/start.sh"]
