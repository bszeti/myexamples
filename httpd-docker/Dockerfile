### No s2i
# FROM registry.redhat.io/rhel8/httpd-24

# Add application sources
# ADD app-src/index.html /var/www/html/index.html

# The run script uses standard ways to run the application
# CMD run-httpd

### With s2i
FROM registry.redhat.io/rhel8/httpd-24

USER 0
ADD app-src /tmp/src

RUN chown -R 1001:0 /tmp/src
USER 1001

# Let the assemble script install the dependencies
# RUN ls -lasR /tmp | tee -a /tmp/assemble.log
# RUN pwd 2>&1 | tee -a /tmp/assemble.log
# RUN ls -lasR ./ 2>&1 | tee -a /tmp/assemble.log
RUN sh -x /usr/libexec/s2i/assemble 2>&1 | tee -a /tmp/assemble.log

# RUN cat /etc/httpd/conf.d/ssl.conf | tee -a /tmp/assemble.log

# The run script uses standard ways to run the application
CMD /usr/libexec/s2i/run

