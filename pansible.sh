#!/usr/bin/env bash

# Run from stack@undercloud, will create an ansible inventory file from nova list.
# Run ansible all -i inventory --list-host.

. stackrc
user="ansible_user=heat-admin"
sudo yum install -y -q -e 0 crudini ansible
nova list | awk '{print $4 "\t" $12}' | grep co > output.txt &&  sed -i s/ctlplane=//g output.txt

echo "[controller]" >> inventory
#if ! grep -q controllers inventory; then
#     echo "[controllers]" >> inventory
#fi
for i in $(grep controller output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done

echo "[compute]" >> inventory
for i in $(grep compute output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done

echo "[swift-storage]" >> inventory
for i in $(grep "swift-storage" output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done

echo "[ceph-storage]" >> inventory
for i in $(grep "ceph-storage" output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done

echo "[block-storage]" >> inventory
for i in $(grep "block-storage" output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done


#cleanup
#rm output.txt

# Show ansible inventory groups
ansible localhost -i inventory -m debug -a 'var=groups'