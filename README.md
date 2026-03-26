# Ansible Role : ansible-alfresco-v5

Déploiement complet d'**Alfresco Community Content Services 23.2.1** sur RHEL/Rocky Linux 8/9/10 et Debian/Ubuntu.

## Composants installés

| Composant | Version | Description |
|-----------|---------|-------------|
| PostgreSQL | 16 | Base de données |
| Java OpenJDK | 17 | Environnement d'exécution |
| Apache Tomcat | 10.1.x | Serveur d'applications |
| Apache ActiveMQ | 5.18.x | Broker de messages |
| Alfresco ACS | 23.2.1 | Plateforme ECM |
| Alfresco Search Services | 2.0.9.1 | Moteur de recherche (Solr) |
| Transform Core AIO | 5.1.0 | Transformations de documents |
| Alfresco Content App | 4.4.1 | Interface Angular |
| Nginx | latest | Reverse proxy |

## Systèmes supportés

- **RHEL Family** : RHEL 8/9/10, Rocky Linux 8/9, AlmaLinux 8/9
- **Debian Family** : Ubuntu 22.04+, Debian 11+

## Variables principales

### `vars/main.yml` (non-surchargeable facilement)

| Variable | Valeur par défaut | Description |
|----------|-------------------|-------------|
| `alf_home` | `/srv/alfresco` | Répertoire d'installation |
| `alf_user` | `alfresco` | Utilisateur système |
| `acs_version` | `23.2.1` | Version Alfresco |
| `tomcat_full` | `10.1.39` | Version Tomcat |
| `activemq_version` | `5.18.7` | Version ActiveMQ |
| `db_pass` | `alfresco` | Mot de passe PostgreSQL |
| `solr_shared_secret` | `secret` | Secret partagé Solr/Alfresco |
| `keystore_password` | `mp6yc0UD9e` | Mot de passe keystore |

### `defaults/main.yml` (surchargeable)

| Variable | Valeur par défaut | Description |
|----------|-------------------|-------------|
| `alfresco_install_aca` | `true` | Installer ACA |
| `alfresco_install_nginx` | `true` | Installer Nginx |
| `nginx_server_name` | `localhost` | Nom de serveur Nginx |
| `nginx_port` | `80` | Port HTTP |

## Utilisation

### Inventaire

```ini
[alfresco]
192.168.11.11 ansible_user=desko ansible_become=yes ansible_become_method=sudo
```

### Playbook

```yaml
---
- hosts: alfresco
  become: yes
  roles:
    - role: ansible-alfresco-v5
```

### Exécution

```bash
ansible-playbook -i tests/inventory tests/test.yml
```

### Surcharger des variables

```yaml
- hosts: alfresco
  become: yes
  roles:
    - role: ansible-alfresco-v5
      vars:
        nginx_server_name: "alfresco.mondomaine.com"
        db_pass: "MonMotDePasseSecurise"
```

## Accès après installation

- **Alfresco Share** : `http://<ip>:8080/share` (admin/admin)
- **Alfresco Admin** : `http://<ip>:8080/alfresco`
- **ACA** : `http://<ip>/`
- **Solr Admin** : `http://<ip>:8983/solr`

## Auteur

**Désiré KOFFI** - SysAdmin Infra & DevOps
