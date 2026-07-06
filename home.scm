(use-modules (gnu home)
	     (gnu home services)
     	     (gnu home services desktop)
	     (gnu home services shells)
     	     (gnu home services sound)
	     (gnu home services niri)
	     (gnu home services syncthing)
	     (gnu services)
	     (guix gexp)
	     (gnu packages wm)
	     (gnu packages xdisorg)
	     (gnu packages xorg)
	     (gnu packages version-control)
	     (gnu packages nwg-shell)
	     (gnu packages admin)
	     (gnu packages emacs)
	     (gnu packages terminals)
	     (gnu packages chromium)
	     (gnu packages containers)
	     (gnu packages pulseaudio)
	     (gnu packages package-management)
	     (gnu packages mate)
	     (gnu packages music)
	     (gnu packages fonts))
(home-environment
 (packages (list fuzzel
		 waybar
		 btop
		 git
		 picard
		 nwg-look
		 fastfetch
		 emacs-pgtk
		 distrobox
		 alacritty
		 pavucontrol
		 ungoogled-chromium
		 font-nerd-symbols
		 flatpak
		 mate-polkit
		 font-jetbrains-mono
		 xwayland-satellite))
 (services
  (list
   (service home-bash-service-type
	    (home-bash-configuration
	     (guix-defaults? #t)
	     (aliases '(("ll" . "ls -lah")
			("sys-up" . "sudo guix system reconfigure ~/.config/guix/system.scm")
			("home-up" . "guix home reconfigure ~/.config/guix/home.scm")))))
   (simple-service 'xdg-data-dirs-flatpak
		    home-environment-variables-service-type
		    '(("XDG_DATA_DIRS" . "$HOME/.local/share/flatpak/exports/share:${XDG_DATA_DIRS:-$HOME/.guix-home/profile/share:/run/current-system/profile/share}")))
   ;; Configurar pipewire
   (service home-dbus-service-type)
   (service home-pipewire-service-type
	    (home-pipewire-configuration
	     (enable-pulseaudio? #t)))
   (service home-niri-service-type)
   (service home-syncthing-service-type))))
