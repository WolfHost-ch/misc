# Servers

This repository contains the setup guide and files for the servers

## Table of Contents

- [Server Setup](#server-setup)
  - [Network Setup](#network-setup)
  - [User Setup](#user-setup)
  - [OS Setup](#os-setup)
  - [Post-os Setup](#post-os-setup)
- [Application Setup](#application-setup)
  - [Swarm Setup](#swarm-setup)
    - [First time setup](#first-time-setup)
    - [Add a manager](#add-a-manager)
    - [Add a worker](#add-a-worker)
  - [Storage Setup](#storage-setup)
    - [Create storage](#create-storage)
    - [Connect swarm nodes](#connect-swarm-nodes)
    - [Maintenance](#maintenance)

## Servers Setup

This section contains the setup guide for the servers os

### Network Setup

- **Subnet:** `10.10.0.0/16`
- **Address:**
  - `10.10.110.{X}` - **Managers**
  - `10.10.120.{X}` - **Workers**
  - `10.10.130.{X}` - **Storage**
- **Gateway:** `10.10.40.1`
- **DNS:** `1.1.1.1`, `8.8.8.8`

### User Setup

- **Name:** `Wolfhost`
- **Server:** `{role}{X}`
- **Username:** `wolfhost`
- **Password:** `wolfhost`

### OS Setup

- **OS:** `Ubuntu Server 24.04 LTS`
- **Update install:** `Yes`
- **Language:** `English`
- **Keybord Layout:** `English (US)`
- **Minimal Installation:** `Yes`
- **Third-party option:** `Yes`
- **Network**: `Following the network setup`
- **User:** `Following the user setup`
- **SSH:** `Yes`
- **Import SSH Key:** `From GitHub AdrienRoco`

### Post-os Setup

1. **Send the script to a server:**

   ```bash
   scp ServersSetup.sh wolfhost@{serverIP}:~/
   ```

2. **Run the setup script on server:**

   ```bash
   sudo chmod +x ServersSetup.sh
   ~/ServersSetup.sh
   ```

## Application Setup

This section contains the setup guide for the managers machines

### Swarm Setup

- **First time setup:**

  ```bash
  sudo docker swarm init --advertise-addr 10.10.110.{manager1}
  ```

- **Add a manager:**

  - Get the join token on a manager node:

  ```bash
  sudo docker swarm join-token manager
  ```

  - Run the command on the new manager node:

  ```bash
  sudo docker swarm join --token {token} 10.10.110.{managerX}:{port}
  ```

  - Drain the node:

  ```bash
  sudo docker node update --availability drain {nodeID}
  ```

- **Add a worker:**

  - Get the join token on a manager node:

  ```bash
  sudo docker swarm join-token worker
  ```

  - Run the command on the new worker node:

  ```bash
  sudo docker swarm join --token {token} 10.10.110.{managerX}:{port}
  ```

### Storage Setup

- **Create storage:**

  - Peer all storage node on storage1 node:

  ```bash
  sudo gluster peer probe {storage2}
  sudo gluster peer probe {storage3}
  ...
  ```

  - Verify the peer status:

  ```bash
  sudo gluster peer status
  ```

  - Create the volume with 3 replicas:

  ```bash
  sudo gluster volume create gv0 replica 3 transport tcp \
  storage1:/data/dockers/brick1 \
  storage2:/data/dockers/brick1 \
  storage3:/data/dockers/brick1
  ```

  - Start and verify the volume:

  ```bash
  sudo gluster volume start gv0
  sudo gluster volume info
  ```

- **Connect swarm nodes:**

if script is run on storage node first, verify first if the volume is mounted

- Mount the volume:

  ```bash
  sudo mount -t glusterfs {storage1}:/gv0 /mnt/dockerdata
  ```

- Mount the volume on boot:

  ```bash
  echo "{storage1}:/gv0 /mnt/dockerdata glusterfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
  ```

- Verify the mount:

  ```bash
  df -h
  ```

- **Maintenance:**

  - View the volume status:

  ```bash
  sudo gluster volume status gv0
  ```

  - View detailed info about the volume:

  ```bash
  sudo gluster volume info gv0
  ```

  - Heal the volume in case of any issues:

  ```bash
  sudo gluster volume heal gv0
  ```

  - Add a new brick to the volume:

  ```bash
  sudo gluster volume add-brick gv0 replica 3 {serverX+}:/data/glusterfs/brick1
  ```

  - Rebalance the volume:

  ```bash
  sudo gluster volume rebalance gv0 start
  ```
