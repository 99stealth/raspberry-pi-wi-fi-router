#Make Wi-Fi router with your Raspberry PI
Script `install_ap.sh` can help you to make Wi-Fi router with your Raspberry Pi.
This script is tested on such external Wi-Fi chipsets as
* Atheros AR9271
* Realtek RTL8188EUS
### How to run
It's easy, just execute the script
```bash
./install_ap.sh
```
### Results
If your wireless chipset is not in list above then you will see next message
```
[-] Your driver is not suported yet. Exit
```
If everything is in order then you will see next result
```
[+] Installation is launched. It will take several minutes
[+] Update repositories data
[!] hostapd is absent and will be installed
[+] hostapd has been installed
[!] isc-dhcp-server is absent and will be installed
[+] isc-dhcp-server has been installed
[!] Fixing issue with hostapd
[!] Setup configuration files
[!] IPTables settings update
[+] Service hostapd has been added to startup
[+] Service isc-dhcp-server has been added to startup
```
