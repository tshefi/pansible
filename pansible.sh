#!/usr/bin/env bash
# To use copy this line:
# wget https://raw.githubusercontent.com/tshefi/pansible/master/pansible.sh  && chmod +x pansible.sh && ./pansible.sh

STACKRC="/home/stack/stackrc"
OVERRC="/home/stack/overcloudrc"
user="ansible_user=heat-admin"


if [ $(whoami) != "stack" ]; then
  echo "Please run as stack user on the undercloud node."
  exit 1
fi

sudo yum install -y python-virtualenv gcc crudini ansible

# Run from stack@undercloud, will create an ansible inventory file from nova list.
# Run ansible all -i inventory --list-host.

# Delete previous run's data files if exist(s).
if [ -f ./inventory ]; then
  printf "Existing inventory file found, removing first..."
  rm -f ./inventory ./output.txt
  echo "Done"
fi

if [ ! -f ./cirros-0.4.0-x86_64-disk.img ]; then
  wget -4 http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
  qemu-img convert -f qcow2 -O raw cirros-0.4.0-x86_64-disk.img cirros-0.4.0-x86_64-disk.raw
fi

. $STACKRC
openstack server list | awk '{print $4 "\t" $8}' | grep c > output.txt &&  sed -i s/ctlplane=//g output.txt

echo "[controller]" >> inventory
for i in $(grep controller output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done

echo "[compute]" >> inventory
for i in $(grep compute output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done

echo "[swift-storage]" >> inventory
for i in $(grep "swift-storage" output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done

echo "[ceph]" >> inventory
for i in $(grep "ceph" output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done

echo "[block-storage]" >> inventory
for i in $(grep "block-storage" output.txt | awk '{print $2}'); do echo $i$user >> inventory ; done


#cleanup temp file
rm output.txt

# Show ansible inventory groups
ansible localhost -i inventory -m debug -a 'var=groups'

if [ ! -f ./get-pip.py ]; then
  curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
fi

sudo pip install pip --upgrade || sudo pip-3 install pip-3 --upgrade
sudo pip install virtualenv --upgrade || sudo pip-3 install virtualenv --upgrade


virtualenv ~/.pansible
. ~/.pansible/bin/activate
pip install pip --upgrade || pip-3 install pip-3 --upgrade

# sudo python get-pip.py
pip install shade || pip-3 install shade    # Queens follow -> https://bugzilla.redhat.com/show_bug.cgi?id=1453089
sudo yum install libselinux-python -y
echo "Now that we have a working invetory, get our playbook."
# Clone Ansible preflight.yml
if [ ! -f ./preflight.yml ]; then
  wget https://raw.githubusercontent.com/tshefi/pansible/master/preflight.yml
fi

echo "Sourced overcloudrc, update floating network name."
. $OVERRC

if openstack network list | grep public > /dev/null; then
   sed -i s/NetName/public/g /home/stack/preflight.yml
else
   sed -i s/NetName/nova/g /home/stack/preflight.yml
fi

# swap qcow2 for raw on preflight.yaml in case of ceph.
if openstack server list | awk '{print $4 "\t" $8}' | grep ceph; then
   sed -i s/qcow2/raw/g /home/stack/preflight.yml
   sed -i s/cirros-0.4.0-x86_64-disk.img/cirros-0.4.0-x86_64-disk.raw/g /home/stack/preflight.yml
fi

echo "Start running ansible preflight.yml."
#Run ansible preflight.yml
ansible-playbook -i inventory  preflight.yml
echo
echo "You should now have a running instance inst1."
openstack server list
echo

echo "A public glance image:"
openstack image list
echo

echo "A public nova flavor:"
openstack flavor list
echo

echo "One attached volume:"
openstack volume list | grep in-use
echo

echo "One swift object:"
openstack object list container1
echo

deactivate
