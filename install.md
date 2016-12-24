# Install Guide for Vagrant Oracle

### 0. Preparation

Make sure that your environment is set up.

The following two tools are intended to use:

* Virtualbox : [https://www.virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads)

* Vagrant : [https://www.vagrantup.com/downloads.html](https://www.vagrantup.com/downloads.html)

Add them to the `PATH` environment variable.

### 1. Install `vagrant-proxyconf` and `vagrant-vbguest` plugins

```
vagrant plugin install vagrant-proxyconf
```

```
vagrant plugin install vagrant-vbguest
```

Make sure both of them are successfully installed:

```
vagrant plugin list
```

### 2. Download Oracle package from oracle site

It is available on [http://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html).

Place the `oracle.xxx-xxx.rpm.zip` into the `sync/oracle` folder.

### 3. Make it up and running!

Start vagrant:

```
vagrant up
```

If you do not use proxy:

```
USE_PROXY=false vagrant up
```

#### 3.1 Ruby environment variables

You can set the following environment variables:

* `USE_PROXY`
* `BOX`
* `BOX_URL`
* `HOSTNAME`

> All of them are set by default.


