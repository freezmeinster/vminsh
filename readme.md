# Jangan gunakan Vmin untuk produksi ya !!!

Vmin adalah sebuah skrip sederhana yang mampu melakukan manajemen Virtual Machine berbasis Qemu + KVM.
Vmin ini dibangun di atas Slackware 15.0 dan tidak pernah ditest di luar lingkungan itu. 
Vmin tidak membutuhkan dependensi lain selain Qemu. 

Beberapa fungsi yang telah ada antara lain :
* Membuat VM
* Menjalankan VM, tampilan VM dapat diakses lewat VNC atau langsung lewat GUI Qemu
* Mematikan VM
* Menghapus VM
* Mampu membuat virtual Bridge 
* Menyediakan sistem dhcp server sendiri berbasis dnsmasq
* Mampu melakukan setting NAT memanfaatkan iptables

Berikut beberapa screenshot nya

* Ini adalah keluaran dari perintah `sudo vmin.sh list`
![image](https://raw.githubusercontent.com/freezmeinster/vminsh/master/screenshot/2022-06-29_08-19.png)

* Ini adalah proses pembuatan VM ketika kita mengetikan perintah `sudo vmin.sh create`
![image](https://raw.githubusercontent.com/freezmeinster/vminsh/master/screenshot/2022-06-29_08-20.png) 

# Installasi

Installasiunya sangat mudah berikut langkahnya :
* Clone repositori ini 
* Buat symbolic link vmin.sh ke /usr/local/bin
* Sesuikan parameter skrip sesuai keinginan kita
* Init vmin dengan perintah `sudo vmin.sh setup base`
* Setup Virtual Bridge dengan perintah `sudo vmin.sh setup network`
* Setup NAT dengan perintah `sudo vmin.sh setup nat`
* Setup fitur DHCP dengan perintah `sudo vmin.sh setup dhcp`
* Mulailah membuat VM dengan perintah `sudo vmin.sh create`
* Proses installasi VM dapat dilakukan dengan perintah `sudo vmin.sh install <nama vm> <fullpath iso>`
