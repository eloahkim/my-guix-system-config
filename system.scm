;; This is an operating system configuration template for a "desktop" setup
;; without full-blown desktop environments.

(use-modules (gnu)
             (guix channels)
             (nonguix)
             (gnu system nss)
	     (gnu system mapped-devices)
	     (gnu system accounts)
             (gnu services desktop)
	     (gnu services ssh)
	     (gnu services linux)
	     (gnu services containers)
	     (gnu services networking)
             (gnu packages bootloaders)
	     (gnu packages linux)
	     (gnu packages cryptsetup)
	     (gnu packages wm)
             (gnu packages xorg))

(define luks-root
  (mapped-device
    (source (uuid "2509d5eb-584f-49f1-9c63-cebe28e96cbf"))
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

  (kernel linux-lts)
  (firmware (cons* linux-firmware %base-firmware))

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
			 (options "subvol=@log,compress=zstd")
			 (flags '(no-atime))
			 (dependencies (list luks-root)))
		       (file-system
			 (device "/dev/mapper/cryptroot")
			 (mount-point "/gnu/store")
			 (type "btrfs")
			 (options "subvol=@gnu-store,compress=zstd")
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
                 (supplementary-groups '("cgroup" "wheel" "netdev" "audio" "video")))
               %base-user-accounts))

  ;; Add a bunch of window managers; we can choose one at
  ;; the log-in screen with F1.
  (packages (append (list
                     ;; window managers
                     btrfs-progs cryptsetup
		     )
                    %base-packages))

  ;; Use the "desktop" services, which include the X11
  ;; log-in service, networking with NetworkManager, and more.
  (services (append (list
		     (service zram-device-service-type
			      (zram-device-configuration
				(size "4G")
				(compression-algorithm 'zstd)
				(priority 100)))
		     (service openssh-service-type)
		     (service iptables-service-type)
		     (service rootless-podman-service-type
			      (rootless-podman-configuration
			       (subgids
				(list (subid-range (name "kim"))))
			       (subuids
				(list (subid-range (name "kim"))))))
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
                      ;; Set up Nonguix channel in /etc/guix/channels.scm.
                      (guix-service-type
                       config => (guix-configuration
                                   (inherit config)
                                   (channels channels-with-nonguix))))))

  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
