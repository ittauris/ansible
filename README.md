# Ansible – Windows automatizácia

Prostredie pre správu Windows serverov cez Ansible s Kerberos autentifikáciou.

---

## Štruktúra projektu

```
/srv/ansible/
├── ansible.cfg
├── hosts.ini
├── ping_windows.yml
├── configure_winrm.yml
├── install_windows_exporter.yml
├── update_windows.yml
├── group_vars/
│   ├── all.yml        # WinRM + Kerberos konfigurácia
│   ├── windows.yml    # Globálne premenné pre všetky Windows hosty
│   ├── KE.yml         # Premenné pre lokalitu Košice
│   ├── RS.yml         # Premenné pre lokalitu Rožňava
│   ├── TC.yml         # Premenné pre lokalitu Trebišov
│   └── vault.yml      # Zašifrované heslá (ansible-vault)
├── host_vars/         # Overrides pre konkrétne hosty
└── krb5.conf          # Kerberos konfigurácia → skopírovať do /etc/krb5.conf
```

---

## Požiadavky

### Ansible controller (Linux)

```bash
sudo apt install libkrb5-dev krb5-user -y
pip install pywinrm[kerberos] --break-system-packages
```

### Kerberos

```bash
sudo cp krb5.conf /etc/krb5.conf
kinit srv_ansible@TAURIS.LOCAL
klist
```

### Ansible Vault

```bash
ansible-vault encrypt /srv/ansible/group_vars/vault.yml
```

Heslo ulož do súboru pre automatické spúšťanie:

```bash
echo "tvojeheslo" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

---

## Inventory

Lokality sú definované v `hosts.ini`. Každý host patrí do skupiny podľa lokality a zároveň do skupiny `windows`.

| Skupina | Lokalita |
|---------|----------|
| KE      | Košice   |
| RS      | Rožňava  |
| TC      | Trebišov |

Domain Controllery sú v samostatných skupinách:

| Skupina | DC     | Lokalita |
|---------|--------|----------|
| DCKE   | DCKE30 | Košice   |
| DCRS   | DCRS30 | Rožňava  |
| DCTC   | DCTC30 | Trebišov |

> **Poznámka:** DC-čka vyžadujú reštart pre správnu inicializáciu WinRM listenera po aplikovaní GPO.

---

## Semaphore UI

Ansible tasky sú spravované cez Semaphore (Docker kontajner).

### Konfigurácia

| Položka    | Hodnota                                   |
|------------|-------------------------------------------|
| Repository | `https://github.com/ittauris/ansible.git` |
| Branch     | `main`                                    |
| Inventory  | `tauris-windows` (File: `hosts.ini`)      |
| User Creds | `srv_ansible` (Login with password)       |
| Git Creds  | `IT Tauris GIT` (Login with password)     |

### Požiadavky pre Semaphore kontajner

- `/etc/krb5.conf` musí byť nakonfigurovaný pre doménu `TAURIS.LOCAL`
- Timezone Docker hosta musí byť `Europe/Bratislava` (Kerberos vyžaduje max. 5 min. časový rozdiel)
- Semaphore automaticky vykonáva `kinit` pred spustením playbooky pomocou credentials z Key Store

### Spustenie pre konkrétnu lokalitu

V Semaphore template zaškrtni **Prompts → Limit** a zadaj skupinu (napr. `KE`, `RS`, `DC-KE`).

---

## WinRM konfigurácia

### Požiadavky na Windows serveroch

WinRM musí byť nakonfigurovaný cez GPO:

- `Allow remote server management through WinRM` → **Enabled** (IPv4 filter: `*`)
- `Allow unencrypted traffic` → **Enabled**

Pre member servery: GPO linkované na príslušné OU.
Pre DC: nastavenia v `Default Domain Controllers Policy`.

### Overenie na Windows

```powershell
winrm enumerate winrm/config/listener
winrm get winrm/config/service
```

---

## Playbook: Ping / test konektivity

**Súbor:** `ping_windows.yml`

Otestuje WinRM konektivitu a zobrazí informácie o OS.

```bash
# Všetky hosty
ansible-playbook ping_windows.yml

# Konkrétna lokalita
ansible-playbook ping_windows.yml -l KE

# Len DC
ansible-playbook ping_windows.yml -l DC-KE
```

---

## Playbook: WinRM konfigurácia

**Súbor:** `configure_winrm.yml`

Nastaví `AllowUnencrypted = true` a overí konfiguráciu WinRM na všetkých hostoch.

```bash
ansible-playbook configure_winrm.yml
ansible-playbook configure_winrm.yml -l KE
```

---

## Playbook: Windows Update

**Súbor:** `update_windows.yml`

Vyhľadá a nainštaluje `SecurityUpdates` a `CriticalUpdates`. V prípade potreby reštartuje server (timeout 20 minút).

### Spustenie

```bash
# Všetky lokality
ansible-playbook update_windows.yml --vault-password-file ~/.vault_pass

# Konkrétna lokalita
ansible-playbook update_windows.yml -l KE --vault-password-file ~/.vault_pass

# Konkrétny host
ansible-playbook update_windows.yml -l BSKE31 --vault-password-file ~/.vault_pass
```

### Filtrované aktualizácie

`Definition Updates` (Defender) sú zámerne vynechané – aktualizujú sa automaticky.

---

## Playbook: Windows Exporter

**Súbor:** `install_windows_exporter.yml`

Stiahne a nainštaluje `windows_exporter` ako Windows službu. Povolí port vo firewalle a overí že služba beží.

| Parameter  | Hodnota                                           |
|------------|---------------------------------------------------|
| Verzia     | 0.31.3                                            |
| Port       | 9182                                              |
| Kolektory  | cpu, cs, logical_disk, net, os, service, system, memory |

### Spustenie

```bash
# Všetky lokality
ansible-playbook install_windows_exporter.yml --vault-password-file ~/.vault_pass

# Konkrétna lokalita
ansible-playbook install_windows_exporter.yml -l RS --vault-password-file ~/.vault_pass
```

### Overenie po inštalácii

```
http://<server>:9182/metrics
```

---

## Časté problémy

### Kerberos ticket expiroval

```bash
kinit srv_ansible@TAURIS.LOCAL
```

### Kerberos – časový rozdiel

```bash
timedatectl
# Nastaviť ak je UTC
timedatectl set-timezone Europe/Bratislava
```

### WinRM HTTP 500

```powershell
winrm get winrm/config/service
# Nastaviť manuálne ak GPO ešte neaplikovalo
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
```

### WinRM listener ListeningOn = null (DC)

DC vyžaduje reštart pre správnu inicializáciu listenera. Reštartovať mimo pracovnej doby.

### WinRM nedostupný

```powershell
winrm enumerate winrm/config/listener
netstat -ano | findstr :5985
```

### Ansible nenašiel hosty

```bash
ansible-inventory --list
ansible windows -m win_ping --vault-password-file ~/.vault_pass
```
