pvesh get /nodes/emihpvproxmox5/hardware/pci --pci-class-blacklist ""
dmesg | grep 'remapping'
lspci -v
update-initramfs -u -k all
update-grub
vi /etc/default/grub
dmesg | grep -e DMAR -e IOMMU -e AMD-Vi
find /sys/kernel/iommu_groups/ -type l