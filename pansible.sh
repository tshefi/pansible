#!/usr/bin/env bash

# Run from stack@undercloud, will create an ansible inventory file from nova list.
# Run ansible all -i inventory --list-host

. stackrc
sudo yum install -y -q -e 0 crudini
nova list | awk '{print $4 "\t" $12}' | grep co > output.txt &&  sed -i s/ctlplane=//g output.txt

echo "[controllers]" >> inventory
for i in $(grep controller output.txt | awk '{print $2}'); do echo $i >> inventory ; done
echo "[computes]" >> inventory
for i in $(grep compute output.txt | awk '{print $2}'); do echo $i >> inventory ; done

#cleanup
rm output.txt

# Show ansible inventory groups
ansible localhost -i inventory -m debug -a 'var=groups'