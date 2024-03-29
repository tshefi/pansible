#!/usr/bin/env bash
# To use copy this line:
# curl -Ok https://raw.githubusercontent.com/tshefi/pansible/master/pansible.sh  && chmod +x pansible.sh
# ./pansible x   (where x is the amount of instances which would be booted up.
#  Also if you need the ssh key has been fixed...[add how to]

STACKRC="/home/stack/stackrc"
OVERRC="/home/stack/overcloudrc"
user="ansible_user=heat-admin"

# initilaize instance count from input var
INSTANCECOUT=$(($1))
if [ "$INSTANCECOUT" -le 1 ]
then
    INSTANCECOUT=1
fi

# Below isn't working yet, have a way to set which image to use
#INSTANCE_OS=$(($2))
#if [" $INSTANCE_OS" -le ]
#    INSTANCE_OS = cirros
#fi
# Install python if not installed.
function pip_install
{
if hash pip-3 2>/dev/null
then
echo "pip-3 install $@"
    sudo pip-3 install --upgrade $@
    sudo pip-3 install future
elif hash pip 2>/dev/null
then
echo "pip install $@"
    sudo pip install --upgrade $@
    sudo pip install future
fi
}


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
  #wget -4 http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
  curl -Ok4L  https://github.com/cirros-dev/cirros/releases/download/0.4.0/cirros-0.4.0-x86_64-disk.img
  qemu-img convert -f qcow2 -O raw cirros-0.4.0-x86_64-disk.img cirros-0.4.0-x86_64-disk.raw
fi



if [ ! -f ./get-pip.py ]; then
  curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
fi

pip_install virtualenv msgpack-python

virtualenv ~/.pansible
. ~/.pansible/bin/activate
pip_install pip --upgrade
pip3 install 'openstacksdk>=0.39.0,<0.53'
#^ is due to: https://storyboard.openstack.org/#!/story/2008577

# sudo python get-pip.py
pip install shade || pip-3 install shade    # Queens follow -> https://bugzilla.redhat.com/show_bug.cgi?id=1453089
sudo yum install libselinux-python -y
echo "Now that we have a working invetory, get our playbook."
# Clone Ansible preflight.yml
if [ ! -f ./preflight.yml ]; then
  #wget https://raw.githubusercontent.com/tshefi/pansible/master/preflight.yml
  curl -Ok https://raw.githubusercontent.com/tshefi/pansible/master/preflight.yml
fi

echo "Sourced overcloudrc, update floating network name."
. $OVERRC

if openstack network list | grep public > /dev/null; then
   sed -i s/NetName/public/g /home/stack/preflight.yml
else
   sed -i s/NetName/nova/g /home/stack/preflight.yml
fi

# swap qcow2 for raw on preflight.yaml in case of ceph.
if [[ $(cinder get-pools --detail |  awk '/storage_protocol/{print $4}') == ceph ]]; then
   sed -i s/qcow2/raw/g /home/stack/preflight.yml
   sed -i s/cirros-0.4.0-x86_64-disk.img/cirros-0.4.0-x86_64-disk.raw/g /home/stack/preflight.yml
fi

# Swap external net range on preflight.yaml
if [[ $(hostname -s) = seal* ]]; then
   sed -i s:10.0.0.0/24:10.35.21.0/26:g /home/stack/preflight.yml
   sed -i s/10.0.0.210/10.35.21.21/g /home/stack/preflight.yml
   sed -i s/10.0.0.250/10.35.21.31/g /home/stack/preflight.yml
   sed -i s/10.0.0.1/10.35.21.62/g /home/stack/preflight.yml
fi

echo "Start running ansible preflight.yml."
#Run ansible preflight.yml
ansible-playbook preflight.yml -e count=$((INSTANCECOUT))

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

echo "Should you need an ssh key, one was imported ~/.ssh/id_pud.rsa"
deactivate
