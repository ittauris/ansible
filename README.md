# Ansible – Windows automatizácia

Prostredie pre správu Windows serverov cez Ansible s Kerberos autentifikáciou.

---

## Štruktúra projektu

```
/srv/ansible/
├── ansible.cfg
├── hosts.ini
├── install_windows_exporter.yml
├── update_windows.yml
├── group_vars/
│   ├── all.yml        # WinRM + Kerberos konfigurácia, vault referencia
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

Lokalit je definovaných v `hosts.ini`. Každý host patrí do skupiny podľa lokality a zároveň do skupiny `windows`.

| Skupina | Lokalita |
|---------|----------|
| KE      | Košice   |
| RS      | Rožňava  |
| TC      | Trebišov |

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
ansible-playbook update_windows.yml -l ke-server01 --vault-password-file ~/.vault_pass
```

### Filtrované aktualizácie

`Definition Updates` (Defender) sú zámerne vynechané – aktualizujú sa automaticky.

---

## Playbook: Windows Exporter

**Súbor:** `install_windows_exporter.yml`

Stiahne a nainštaluje `windows_exporter` ako Windows službu. Povolí port vo firewalle a overí že služba beží.

| Parameter | Hodnota |
|-----------|---------|
| Verzia    | 0.29.2  |
| Port      | 9182    |
| Kolektory | cpu, cs, logical_disk, net, os, service, system, memory |

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

### WinRM nedostupný

Overiť na Windows strane:

```powershell
winrm enumerate winrm/config/listener
```

### Ansible nenašiel hosty

Overiť inventory:

```bash
ansible-inventory --list
ansible windows -m win_ping --vault-password-file ~/.vault_pass
```
