# **Oh My Zsh Installer with Plugins**

This script automates the installation of **Oh My Zsh**, **Zsh autosuggestions**, and **Zsh syntax highlighting** on a new server. It also allows you to set Zsh as the default shell.

## **Features**
- Installs **Oh My Zsh**.
- Installs **Zsh autosuggestions** and **Zsh syntax highlighting** plugins.
- Optionally sets Zsh as the default shell.
---

## **Prerequisites**
Ensure your server has the following installed:
- `curl`
- `git`
- `zsh` (the script will install it if not already present)

---

## **Installation**
1. Clone this repository or download the script:
   ```bash
   git clone https://github.com/luutuankiet/oh-my-zsh-installer.git
   cd oh-my-zsh-installer
   ```

2. Make the script executable:
   ```bash
   chmod +x install_oh_my_zsh.sh
   ```

3. Run the script with or without arguments:

### **Usage**
```bash
./install_oh_my_zsh.sh [yes|no]
```

- **Arguments:**
  - `yes`: Install Zsh and set it as the default shell.
  - `no` (default): Install Zsh without changing the default shell.

**Examples:**

- Install Oh My Zsh and make it the default shell:
  ```bash
  ./install_oh_my_zsh.sh yes
  ```

- Install Oh My Zsh without changing the default shell:
  ```bash
  ./install_oh_my_zsh.sh no
  ```

- If no argument is passed, it defaults to `no`:
  ```bash
  ./install_oh_my_zsh.sh
  ```

## **License**
This project is licensed under the [MIT License](LICENSE).
