#!/bin/bash
export LC_ALL=C.UTF-8;

VM_CONFIG_FIELDS=(
  "agent" "boot" "bootdisk" "cipassword" "ciuser"
  "cores" "description" "ide2" "ipconfig0" "memory"
  "name" "nameserver" "net0" "numa" "onboot" "ostype"
  "scsi0" "scsihw" "smbios1" "sockets" "sshkeys" "vmgenid"
);

get_vm_host() {
  if [ -z "$(grep "is not running" <<< $1)" ] && [ ! -z "$(grep "out-data" <<< $1)" ] ; then
    host="$(grep "\"out-data\" :" <<< $1 | sed s/"\"out-data\"\ ":// )";
    host="$(printf "$host" | sed s/\"// | tr -d ' ' )";
    echo "{\"$2\":\"$host\"}"
  fi
}

vms="";
vm_ids=$(qm list | awk '{print $1}' | tail +2);
for vm_id in $vm_ids
do
  p="{\"vm_id\":\"$vm_id\"}";
  vm_guest_ip=$(qm guest exec $vm_id -- bash -c "hostname -I")
  vm_guest_hostname=$(qm guest exec $vm_id -- bash -c "hostname")
  p+="$(get_vm_host "$vm_guest_ip" "vm_ip")"
  p+="$(get_vm_host "$vm_guest_hostname" "vm_hostname")"
  
  vm_conf=$(qm config $vm_id);
  for field in "${VM_CONFIG_FIELDS[@]}"
  do
    f_fld=$(grep "$field:" <<< $vm_conf | sed s/"$field: "// )
    [[ ! -z $f_fld ]] && p+="{\"$field\":\"$f_fld\"}"
  done
  vms+="$(echo $p | sed -e 's/}{/,/g' - )";
done

json="$(printf "{\"node_hostname\":\"%s\",\"node_ip\":\"%s\",\"vms_configs\":[%s]}" $(hostname) $(hostname -I) "$(echo $vms | sed -e 's/}{/},{/g' - )")";

curl -X POST http://127.0.0.1:12345 -H "Content-Type: application/json" --data "$json"
#nc -l 12345
