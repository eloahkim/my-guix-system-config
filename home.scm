(use-modules (gnu home)
	     (gnu home services)
     	     (gnu home services desktop)
	     (gnu home services dotfiles)
	     (gnu home services shells)
     	     (gnu home services sound)
	     (gnu home services niri)
	     (gnu home services mpv)
	     (gnu home services syncthing)
	     (gnu home services xdg)
	     (gnu services)
	     (guix gexp)
	     (guix transformations) 	; para o xwayland-satellite com fix
	     (guix packages)
	     (gnu packages)
	     (gnu packages freedesktop)
	     (gnu packages window-management)
	     (gnu packages xdisorg)
	     (gnu packages xorg)
	     (gnu packages version-control)
	     (gnu packages nwg-shell)
	     (gnu packages admin)
	     (gnu packages compression)
	     (gnu packages emacs)
	     (gnu packages emacs-xyz)
	     (gnu packages terminals)
	     (gnu packages bittorrent)
	     (gnu packages maths)
	     (gnu packages containers)
	     (gnu packages virtualization)
	     (gnu packages emulators)
	     (gnu packages pulseaudio)
	     (gnu packages image-viewers)
	     (gnu packages package-management)
	     (gnu packages password-utils)
	     (gnu packages mate)
	     (gnu packages gnome)
	     (gnu packages gnome-xyz)
	     (gnu packages qt)
	     (gnu packages glib)
	     (gnu packages kde-internet)
     	     (gnu packages kde-utils)
	     (gnu packages kde-graphics)
	     (gnu packages music)
	     (gnu packages video)
	     (gnu packages pdf)
	     (gnu packages ncurses)
	     (gnu packages sync)
	     (gnu packages rust-apps)
	     (gnu packages python)
	     (gnu packages python-xyz)
	     (gnu packages fonts)
	     (noctalia)
     	     (nongnu packages mozilla))

;; fix do xwayland-satellite até sair a versão corrigida
;; (define transform
;;   (options->transformation
;;    '((with-commit . "xwayland-satellite=10f985b84cdbcc3bbf35b3e7e43d1b2a84fa9ce2"))))

;; (define xwayland-satellite-fixed
;;   (package
;;     (inherit (transform xwayland-satellite))
;;     (name "xwayland-satellite-fixed")))

(home-environment
 (packages (list rofi
		 waybar
		 playerctl
		 wallust
		 noctalia-git
		 (list glib "bin")
		 virt-manager
		 python
		 python-dbus
		 uv
		 swayidle
		 swaylock
		 swaybg
		 kdeconnect
		 btop
		 keepassxc
		 git
		 (specification->package "steam")
		 pcsx2
		 picard
		 mpv
		 imv
		 qalculate-gtk
		 wlsunset
		 ncurses
		 mako
		 libnotify
		 cliphist
		 wl-clipboard
		 nwg-look
		 qt6ct
		 bibata-cursor-theme
		 udiskie
		 rclone
		 zip
		 unzip
		 7zip
		 fastfetch
		 emacs-pgtk
		 emacs-dashboard
		 emacs-vterm
		 distrobox
		 foot
		 pavucontrol
		 firefox-esr
		 font-nerd-symbols
		 flatpak
		 mate-polkit
		 aria2
		 qbittorrent
		 font-jetbrains-mono
		 font-inter
		 font-google-noto
		 font-google-noto-sans-cjk
		 font-google-noto-serif-cjk
		 font-google-noto-emoji
		 zenity
		 gnome-themes-extra
		 adw-gtk3-theme
		 zathura
		 zathura-pdf-mupdf
		 papirus-icon-theme
		 xwayland-satellite
		 ;; Pacotes do KDE Plasma 
		 ;; ark
		 ;; gwenview
		 ;; kcalc
		 ))

 (services
  (list
   (service home-bash-service-type
	    (home-bash-configuration
	     (guix-defaults? #t)
	     (aliases '(("ll" . "ls -lah")
			("ls" . "ls --color")
			("sys-up" . "sudo guix system reconfigure ~/.config/guix/system.scm")
			("home-up" . "guix home reconfigure ~/.config/guix/home.scm")
			("neofetch-like" . "fastfetch -c neofetch.jsonc")))))

   (simple-service 'xdg-data-dirs-flatpak
		    home-environment-variables-service-type
		    '(("XDG_DATA_DIRS" . "$HOME/.local/share/flatpak/exports/share:${XDG_DATA_DIRS:-$HOME/.guix-home/profile/share:/run/current-system/profile/share}")))

   (simple-service 'flatpak-fonts-copy
                home-activation-service-type
                #~(let* ((home (getenv "HOME"))
                         (target (string-append home "/.local/share/fonts"))
                         (source (string-append home "/.guix-home/profile/share/fonts")))
                    ;; Flatpak/bubblewrap não segue symlinks para o store;
                    ;; por isso é preciso sincronizar com cópia real.
		    ;; O destino é recriado do zero a cada ativação para
		    ;; evitar fontes órfãs (removidas do home.scm, mas ainda
		    ;; copiadas de uma execução anterior).
                    (when (file-exists? target)
                      (delete-file-recursively target))
                    (mkdir-p target)
                    (for-each
                     (lambda (file)
                       (let* ((rel (string-drop file (string-length source)))
                              (dest (string-append target rel)))
                         (mkdir-p (dirname dest))
                         (copy-file file dest)))
                     (find-files source "\\.(ttf|ttc|otf|woff2?)$"))))

   (simple-service 'niri-portals-conf
                home-xdg-configuration-files-service-type
                (list `("xdg-desktop-portal/portals.conf"
                        ,(plain-file "portals.conf" "\
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=gnome
org.freedesktop.impl.portal.Screenshot=gnome
"))))
   
   (simple-service 'local-bin-path
		   home-environment-variables-service-type
		   '(("PATH" . "$HOME/.local/bin:$PATH")))
   
   ;; Configurar pipewire
   (service home-dbus-service-type)
   (service home-pipewire-service-type
	    (home-pipewire-configuration
	     (enable-pulseaudio? #t)))

   ;; Correção bluetooth 
;;    (simple-service 'wireplumber-bt-roles
;; 		   home-xdg-configuration-files-service-type
;;                    (list `("wireplumber/wireplumber.conf.d/51-bluez-roles.conf"
;;                            ,(plain-file "51-bluez-roles.conf" "\
;; monitor.bluez.properties = {
;;   bluez5.roles = [ hfp_ag hsp_ag a2dp_sink a2dp_source ]
;;   bluez5.hfphsp-backend = \"native\"
;; }
;; "))))


   ;; Niri
   (service home-niri-service-type)
   
   ;; MPV
   (service home-mpv-service-type
         (make-home-mpv-configuration
          #:global (make-mpv-profile-configuration
		    #:vo '("gpu-next")
		    #:ao '("pulse")
		    #:hwdec '("vaapi")
		    #:save-position-on-quit? #t
		    #:keep-open 'yes)))

   (service home-xdg-user-directories-service-type
	    (home-xdg-user-directories-configuration
	     (documents "$HOME/Documentos")
	     (download "$HOME/Downloads")
	     (music "$HOME/Músicas")
	     (pictures "$HOME/Imagens")
	     (videos "$HOME/Vídeos")
	     (publicshare "$HOME/Público")
	     (templates "$HOME/Modelos")
	     (projects "$HOME/Projetos")
	     (desktop "$HOME/Área de Trabalho")))

   (service home-syncthing-service-type))))
