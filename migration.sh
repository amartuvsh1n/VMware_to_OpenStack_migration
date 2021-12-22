source .env
source /etc/os-release
. $adminrc

dnf-centos() 
{
    echo debian
    # #add repo
    # dnf install -y epel-release && dnf update;
    # #install packages
    # dnf install -y qemu-utils jq python3-openstackclient;
}

apt-ubuntu()
{
    echo ubuntu
    #apt update;
    #apt install -y qemu-utils jq python3-openstackclient;
}


migration()
{
    # echo start date: $date |& tee /var/log/out.log
    # read all dsName
    jq -r '.[].dsName' vm.json | while read dsName; do
        size=$(jq -r ".[] | select( .dsName == \"$dsName\" ).vms[].disk_size" vm.json)
        ip=$(jq -r ".[] | select( .dsName == \"$dsName\" ).vms[].ip" vm.json)
        flavor=$(jq -r ".[] | select( .dsName == \"$dsName\" ).vms[].flavor" vm.json)
        # read vmname from dsName
        jq -r ".[] | select( .dsName == \"$dsName\" ).vms[].name" vm.json | while read vmname; 
        do
            for sub_name in -ctk '' -flat
            do
                # if space in vmname, swap to %20 
                name=${vmname// /%20}
                dcPath=${dcPath//-/%252d}
                echo curl  -k -u $Username:$Password "$base_url/$name/$name$sub_name.vmdk?dcPath=$dcPath&dsName=$dsName" --output "$vmname$sub_name.vmdk"
                curl  -k -u $Username:$Password "$base_url/$name/$name$sub_name.vmdk?dcPath=$dcPath&dsName=$dsName" --output "$vmname$sub_name.vmdk"
            done

            # convert vmdk to qcow2
            if [ -f "$vmname-flat.vmdk" ] 
            then
                echo qemu-img convert -f vmdk -O qcow2 "$vmname.vmdk" "$vmname.qcow2"
                qemu-img convert -f vmdk -O qcow2 "$vmname$sub_name.vmdk" "$vmname$sub_name.qcow2"
                echo intall virt-io
                virt-v2v -i disk "$vmname.qcow2" -o local -os "./"
                echo openstack image create --disk-format qcow2 --container-format bare --file "$vmname-sda" --public "$vmname"
                openstack image create --disk-format qcow2 --container-format bare --file "$vmname-sda" --public "$vmname"
                echo openstack volume create --bootable  --image "$vmname" --size $size "$vmname volume" 
                openstack volume create --bootable  --image "$vmname" --size $size "$vmname volume" 
                portid=$(openstack port create --network $network --fixed-ip subnet=$subnet,ip-address="$ip" --format value -c id "ip for $vmanem")
                #echo portID=$portid
                echo openstack server create --flavor "$flavor" --volume "$vmname volume" --nic port-id=$portid "$vmname"
                openstack server create --flavor "$flavor" --volume "$vmname volume" --nic port-id=$portid "$vmname"
                #echo "done date: $date" |$ tee /var/log/out.log
            fi

        done
    done
}


case $ID in
    "centos") dnf-centos
        migration
    ;;
    "ubuntu") apt-ubuntu 
        migration
    ;;
    "*") echo "can't find $ID; " ;;
esac
