;; This is an operating system configuration template for a "desktop" setup
;; without full-blown desktop environments.

(use-modules (gnu)
             (guix channels)
             (guix transformations)
             (nonguix)
             (gnu system nss)
	     (gnu system mapped-devices)
             (gnu system accounts)
	     (gnu services desktop)
	     (gnu services ssh)
	     (gnu services linux)
	     (gnu services xorg)
	     (gnu services sddm)
	     (gnu services base)
	     (gnu services containers)
	     (gnu services virtualization)
	     (gnu services networking)
	     (gnu services pm)
             (gnu packages bootloaders)
	     (gnu packages linux)
	     (gnu packages containers)
	     (gnu packages networking)
	     (gnu packages cryptsetup)
	     (gnu packages window-management)
	     (gnu packages hardware)
             (gnu packages xorg))

(define containerd-cgroups-fix
  (options->transformation
   '((with-patch . "go-github-com-containerd-cgroups=/home/kim/.config/guix/containerd-cgroups-fix.patch"))))

(define luks-root
  (mapped-device
    (source (uuid "8a1b66f0-9aed-40fa-abe7-af62dc0c8214"))
    (target "cryptroot")
    (type luks-device-mapping)))

(define channels-with-nonguix
  (list (channel
          (inherit %default-guix-channel)
          (name 'guix)
          (url "https://git.guix.gnu.org/guix.git"))
        (channel
          (name 'nonguix)
          (url "https://gitlab.com/nonguix/nonguix")
          (introduction
           (make-channel-introduction
            "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
            (openpgp-fingerprint
             "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))))

(define nonguix-signing-key
  (plain-file "nonguix.pub" 
    "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))

(define guix-moe-signing-key
  (plain-file "guix-moe.pub"
    "(public-key (ecc (curve Ed25519) (q #552F670D5005D7EB6ACF05284A1066E52156B51D75DE3EBD3030CD046675D543#)))"))

(operating-system
  (host-name "guix-btw")
  (timezone "America/Maceio")
  (locale "pt_BR.utf8")
  (keyboard-layout (keyboard-layout "br" "abnt2"))

  (kernel linux-lts)
  (firmware (cons* linux-firmware %base-firmware))

    ;; Desativa o teclado interno com problema (atkbd/i8042)
  (kernel-arguments
   (append (list "modprobe.blacklist=atkbd" "i8042.nokbd"
		 "ideapad_laptop.no_bt_rfkill=1")
           %default-kernel-arguments))


  ;; Use the UEFI variant of GRUB with the EFI System
  ;; Partition mounted on /boot/efi.
  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (targets '("/efi"))))

  (mapped-devices (list luks-root))

  ;; Assume the target root file system is labelled "my-root",
  ;; and the EFI System Partition has UUID 1234-ABCD.
  (file-systems (append
                 (list (file-system
                         (device "/dev/mapper/cryptroot")
                         (mount-point "/")
                         (type "btrfs")
			 (options "subvol=@,compress=zstd")
			 (flags '(no-atime))
			 (dependencies (list luks-root)))
		       (file-system
			 (device "/dev/mapper/cryptroot")
			 (mount-point "/home")
			 (type "btrfs")
			 (options "subvol=@home,compress=zstd")
			 (flags '(no-atime))
			 (dependencies (list luks-root)))
		       (file-system
			 (device "/dev/mapper/cryptroot")
			 (mount-point "/var/log")
			 (type "btrfs")
			 (options "subvol=@var_log,compress=zstd")
			 (flags '(no-atime))
			 (dependencies (list luks-root)))
		       (file-system
			 (device "/dev/mapper/cryptroot")
			 (mount-point "/gnu/store")
			 (type "btrfs")
			 (options "subvol=@gnu_store,compress=zstd")
			 (flags '(no-atime))
			 (dependencies (list luks-root)))

                       (file-system
                         (device (file-system-label "ESP"))
                         (mount-point "/efi")
			 (mount-may-fail? #f)
                         (type "vfat")))
                 %base-file-systems))

  (users (cons (user-account
                 (name "kim")
                 (comment "Kim")
                 (group "users")
                 (supplementary-groups '("cgroup" "wheel" "netdev" "audio" "video" "i2c" "lp" "libvirt" "kvm")))
               %base-user-accounts))
  (groups (cons (user-group (name "i2c"))
		%base-groups))
  

  ;; Add a bunch of window managers; we can choose one at
  ;; the log-in screen with F1.
  (packages (append (list
                     btrfs-progs cryptsetup ddcutil
		     )
                    %base-packages))

  ;; Use the "desktop" services, which include the X11
  ;; log-in service, networking with NetworkManager, and more.
  (services (append (list
		     (service zram-device-service-type
			      (zram-device-configuration
				(size "6G")
				(compression-algorithm 'zstd)
				(priority 100)))
		     ;; libvirt
		     (service virtlog-service-type)
		     (service libvirt-service-type)
		     ;; config necessária para screen lockers como o swaylock
		     (service screen-locker-service-type
			      (screen-locker-configuration
				(name "swaylock")
				(program (file-append swaylock "/bin/swaylock"))
				(using-pam? #t)
				(using-setuid? #f)))
		     (simple-service 'ddcutil-udev-rules
				     udev-service-type
				     (list ddcutil))
		     (service bluetooth-service-type)
		     (service openssh-service-type)
		     (service iptables-service-type
			      (iptables-configuration
			       (ipv4-rules (plain-file "iptables.rules" "*filter
:INPUT DROP
:FORWARD DROP
:OUTPUT ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# libvirt
-A INPUT -i virbr0 -j ACCEPT
-A FORWARD -i virbr0 -j ACCEPT
-A FORWARD -o virbr0 -j ACCEPT

# Acesso SSH
-A INPUT -p tcp --dport 22 -j ACCEPT

# Navidrome
-A INPUT -p tcp --dport 4533 -j ACCEPT

# Jellyfin
-A INPUT -p tcp --dport 8096 -j ACCEPT
-A INPUT -p udp --dport 1900 -j ACCEPT
-A INPUT -p udp --dport 7359 -j ACCEPT

# Steam Remote Play
-A INPUT -p tcp --dport 27036 -j ACCEPT
-A INPUT -p udp --dport 27031:27036 -j ACCEPT

# KDE Connect
-A INPUT -p tcp --dport 1714:1764 -j ACCEPT
-A INPUT -p udp --dport 1714:1764 -j ACCEPT

COMMIT
"))
			       (ipv6-rules (plain-file "ip6tables.rules" "*filter
:INPUT DROP
:FORWARD DROP
:OUTPUT ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p tcp --dport 4533 -j ACCEPT
-A INPUT -p tcp --dport 8096 -j ACCEPT
-A INPUT -p tcp --dport 1714:1764 -j ACCEPT
-A INPUT -p udp --dport 1714:1764 -j ACCEPT
COMMIT
"))))
		     
		     (service rootless-podman-service-type
			      (rootless-podman-configuration
			       (podman (containerd-cgroups-fix podman))
			       (subgids
				(list (subid-range (name "kim"))))
			       (subuids
				(list (subid-range (name "kim"))))))
		     (service power-profiles-daemon-service-type)
		     (service gnome-keyring-service-type)

		     ;; KDE Plasma
		     ;; (service sddm-service-type
		     ;; 	      (sddm-configuration
		     ;; 	       (theme "breeze")))
		     ;; (service plasma-desktop-service-type)
		     ;; (service kwallet-service-type)
		     
                     ;; Use substitutes from Nonguix.
                     (simple-service 'substitute-servers guix-service-type
                       (guix-extension
                         (substitute-urls
                          (list "https://cache-cdn.guix.moe"
				"https://substitutes.nonguix.org"))
                         (authorized-keys
                          (list guix-moe-signing-key
				nonguix-signing-key)))))
                    (modify-services %desktop-services
				     (delete gdm-service-type)
                      ;; Set up Nonguix channel in /etc/guix/channels.scm.
                      (guix-service-type
                       config => (guix-configuration
                                   (inherit config)
                                   (channels channels-with-nonguix))))))

  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
