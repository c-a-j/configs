update-all:
  ansible-playbook main.yml -K

update-pi:
  bash user/pi/setup.sh

update-nvim:
  ansible-playbook playbooks/nvim-config.yml

update-alacritty:
  ansible-playbook playbooks/terminal-config.yml
  
update-user-env:
  ansible-playbook playbooks/env-config-user.yml

update-user-scripts:
  ansible-playbook playbooks/user-scripts.yml

update-workmux:
  ansible-playbook playbooks/workmux-config.yml

update-herdr:
  ln -f $HOME/configs/user/herdr/config.toml $HOME/.config/herdr/config.toml

update-sway-config:
  ansible-playbook playbooks/sway-config.yml

update-sway:
  ansible-playbook playbooks/sway.yml -K

update-terminal:
  ansible-playbook playbooks/terminal-config.yml
