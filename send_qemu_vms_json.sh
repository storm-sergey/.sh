#!/bin/bash
export LC_ALL=C.UTF-8;

HOST="http://10.0.19.18:13579"


# random (1 - 20 minutes) sleep for unloading server app
sleep .$[ (RANDOM % 20) + 1]m

# fields list from the command "qm config $vm_id"
VM_CONFIG_FIELDS=(
  "agent" "boot" "bootdisk" "cipassword" "ciuser"
  "cores" "description" "ide2" "ipconfig0" "memory"
  "name" "nameserver" "net0" "numa" "onboot" "ostype"
  "scsi0" "scsihw" "smbios1" "sockets" "sshkeys" "vmgenid"
);

# virtual machine info from the machine agent
get_vm_host() {
  if [ -z "$(grep "is not running" <<< $1)" ] && [ ! -z "$(grep "out-data" <<< $1)" ] ; then
    host="$(grep "\"out-data\" :" <<< $1 | sed s/"\"out-data\"\ ":// )";
    host="$(printf "$host" | sed s/\"// | tr -d ' ' )";
    echo "{\"$2\":\"$host\"}"
  fi
}

# virtual machines info from the node
vms="";
vm_ids=$(qm list | awk '{print $1}' | tail +2);
for vm_id in $vm_ids
do
  p="{\"vm_id\":\"$vm_id\"}";
  if [ "$DEBUG" = true ] ; then
    vm_guest_ip="0.0.0.0"
    vm_guest_hostname="debug"
  # else
    # all VMs don't have a guest agent
    # and these next two commands are long await operations:
    # vm_guest_ip=$(qm guest exec $vm_id -- bash -c "hostname -I")
    # vm_guest_hostname=$(qm guest exec $vm_id -- bash -c "hostname")
  fi
  p+="$(get_vm_host "$vm_guest_ip" "vm_ip")"
  p+="$(get_vm_host "$vm_guest_hostname" "vm_hostname")"
  
  vm_conf=$(qm config $vm_id);
  for field in "${VM_CONFIG_FIELDS[@]}"
  do
	  f_fld=$(grep "$field:" <<< $vm_conf | sed s/"$field: "// | tr -d '%' | tr -d '\\' | tr -d '[' | tr -d ']' | tr -d '(' | tr -d ')' | tr -d '/' | tr -d '"')
    [[ ! -z $f_fld ]] && p+="{\"$field\":\"$f_fld\"}"
  done
  vms+="$(echo $p | sed -e 's/}{/,/g' )";
done
# | sed -e 's/\%//g' | sed -e 's/\\//g'
# node hardware info
hostname="$(hostname)"
ip="$(hostname -I)"
cpu_model="$(lscpu | grep -i model\ name: | sed s/Model\ name:// | sed s/\ /_/ | tr -d ' ')"
cpu_cores="$(lscpu | grep -i ^CPU\(s\): | sed s/CPU\(s\):// | tr -d ' ')"
ram_gib="$(free -h | awk '{print $2}' | tail +2 | head -1)"
disks="$(lsblk | grep ^sd | awk '{print $1, $4}' | sed s/\ /_/)"
raid_controller="$(lspci | grep -i RAID\ bus\ controller: | sed s/........RAID\ bus\ controller:// | tr -d ' ')"

# empty string checking
[[ ! "$hostname" ]] && hostname="null"
[[ ! "$ip" ]] && ip="null"
[[ ! "$cpu_model" ]] && cpu_model="null"
[[ ! "$cpu_cores" ]] && cpu_cores="null"
[[ ! "$ram_gib" ]] && ram_gib="null"
[[ ! "$disks" ]] && disks="null"
[[ ! "$raid_controller" ]] && raid_controller="null"
[[ ! "$vms" ]] && vms="null"

# array distruction
cpu_model="$(echo -e $cpu_model | sed s/\ /-/g)"
ram_gib="$(echo -e $ram_gib | sed s/\ /-/g)"
disks="$(echo -e $disks | sed s/\ /-/g)"
raid_controller="$(echo -e $raid_controller | sed s/\ /-/g)"
vms="$(echo -e $vms | sed -e 's/}{/},{/g' | sed s/\ /-/g)"

# make json
json="$(printf "{\"node_hostname\":\"%s\",\"node_ip\":\"%s\",\"node_cpu_model\":\"%s\",\"node_cores\":\"%s\",\"node_ram_gib\":\"%s\",\"node_disks\":\"%s\",\"node_raid_controller\":\"%s\",\"vms_configs\":[%s]}\n" $hostname $ip $cpu_model $cpu_cores $ram_gib $disks $raid_controller $vms)";

#echo $json

response="$(curl -s -X POST $HOST -H "Content-Type: application/json" --data "$json")"
if [[ $response == '<p>Success</p>' ]] ; then
  echo 'The script have got the code 200'
  echo $response
  exit 0
fi
echo "The script have got the resopnse $response"
exit 204
