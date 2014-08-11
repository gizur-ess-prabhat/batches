OData producer on top of MySQL
==============================

OData producer built using these libraries:

 * http://odatamysqlphpconnect.codeplex.com/
 * http://odataphpproducer.codeplex.com


Usage
-----

Prerequisites:

 * docker needs to be installed.

Installation: `docker build --rm .`

Run the container in daemon mode: `docker run -d -p 80:80 -p 443:443 [IMAGE ID]`. The 80 and 443 ports that have been exposed from the container will be routed from the host to the container using the `-p` flag.


Interactive mode
----------------

When developing, it is usefull to connect to the containers shell:

```
# Start a container and connect to the shell (remove when stopped)
docker run -t -i --rm [IMAGE ID] /bin/bash

# Start the services
supervisord &> /tmp/out.txt &

# Check that all processes are up
ps -ef
```


Production
----------

The included MySQL server should not be used for production. Disable it by commenting out the
`[program:mysql]` parts with `#` in supervisord.conf

MySQL credentials for external server should be passed as environment variables that are set when starting the container.

Here is an example: `docker run -t -i -e USERNAME="admin", PASSWORD="secret", HOSTNAME="hostname" base /bin/bash`






