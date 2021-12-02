source .env
source /etc/os-release

dnf-centos() 
{
    #add repo
    dnf install -y epel-release && dnf update;
    #install packages
    dnf install -y qemu-utils jq;
}

apt-ubuntu()
{
    apt update;
    apt install -y qemu-utils jq;
}


migration()
{
    # read all dsName
    jq -r '.[].dsName' vm.json | while read dsName; do
        # read vmname from dsName
        jq -r ".[] | select( .dsName == \"$dsName\" ).vms[].name" vm.json | while read vmname; do
            for sub_name in -ctk '' -flat
            do
                # if space in vmname, swap to %20 
                name=${vmname// /%20}
                curl  -k -u $Username:$Password "$base_url/$name/$name$sub_name.vmdk?dcPath=$dcPath&dsName=$dsName" > "$vmname$sub_name.vmdk"

                # convert vmdk to qcow2
                if [ -z $sub_name ] 
                then
                    qemu-img convert -f vmdk -O qcow2 "$vmname$sub_name.vmdk" "$vmname$sub_name.qcow2"
                fi

            done
        done
    done
}


case $OS in
    "centos") dnf-centos
        migration
    ;;
    "ubuntu") apt-ubuntu 
        migration
    ;;
    "*") echo "can't find $OS; " ;;
esac

