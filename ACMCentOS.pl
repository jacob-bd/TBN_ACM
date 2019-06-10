#!/usr/bin/perl
####################
# This script will configure Turbonomic servers running on CentOS / RedHat to be added as APM Target
####################

print "\n\n\n\nConfiguring your Turbonomic Instance for ACM. This can take up to a couple minutes.\n\n\n\n\n"; 

print "\n\n\n\nCopying JMX  jar from /tmp to target directory and updating permissions.\n\n\n\n\n";

#my $url = 'https://archive.apache.org/dist/tomcat/tomcat-7/v7.0.79/bin/extras/catalina-jmx-remote.jar';
#system "curl -o /usr/share/java/tomcat/catalina-jmx-remote.jar $url";
system "cp /tmp/catalina-jmx-remote.jar /usr/share/java/tomcat/catalina-jmx-remote.jar";
system "chmod 707 /usr/share/tomcat/lib/catalina-jmx-remote.jar";

print "\n\n\n\nBacking up /tomcat/server.xml, tomcat.conf and /etc/my.cnf.d/turbo.cnf....\n\n\n\n\n";
use File::Copy;
copy("/etc/tomcat/server.xml", "/etc/tomcat/server.xml.original");
copy("/etc/tomcat/tomcat.conf", "/etc/tomcat/tomcat.conf.original");
copy("/etc/my.cnf.d/turbo.cnf", "/etc/my.cnf.d/turbo.cnf.original");

print "\n\n\n\nFile Backup Done (backup files named *.original)....\n\n\n\n\n";

#######################################################################################################
print "\n\n\n\nConfiguring /etc/tomcat/tomcat.conf....\n\n\n\n\n";

open my $in, '<', '/etc/tomcat/tomcat.conf' ;
my $content = do { undef $/; <$in> };
close $in;


my $first_line = quotemeta ' to JAVA_OPTS or to CLASSPATH'; 
my $second_line = quotemeta 'JAVA_OPTS=eval $MY_JAVA_OPTS /usr/bin/free'; 
my $insert = 'CATALINA_OPTS="-Djava.awt.headless=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=true" -Dcom.sun.management.jmxremote.password.file=/usr/share/tomcat/conf/jmxremote.password -Dcom.sun.management.jmxremote.access.file=/usr/share/tomcat/conf/jmxremote.access'; 


$content =~ s/(?<=$first_line) .*? (?=$second_line)/\n$insert\n/xs; 


open my $out, '>', '/etc/tomcat/tomcat.conf'; 
print $out $content; 
close $out;


#######################################################################################################
print "\n\n\n\nConfiguring /etc/tomcat/server.xml....\n\n\n\n\n";

open my $in2, '<', '/etc/tomcat/server.xml' ;
my $content2 = do { undef $/; <$in2> };
close $in2;


my $first_line2 = quotemeta 'ThreadLocalLeakPreventionListener" />'; 
my $second_line2 = quotemeta '<!-- Global JNDI resources'; 
my $insert2 = '<Listener className="org.apache.catalina.mbeans.JmxRemoteLifecycleListener" rmiRegistryPortPlatform="7050" rmiServerPortPlatform="7051" />'; 


$content2 =~ s/(?<=$first_line2) .*? (?=$second_line2)/\n$insert2\n/xs; 


open my $out2, '>', '/etc/tomcat/server.xml'; 
print $out2 $content2; 
close $out2;

########################################################################################
print "\n\n\n\nCreating jmxremote.access and jmxremote.password files under /usr/share/tomcat/conf/....\n\n\n\n\n";

open my $jmxaccess, '>','/usr/share/tomcat/conf/jmxremote.access';
print $jmxaccess "controlRole readwrite";
close $jmxaccess;

open my $jmxpassword, '>','/usr/share/tomcat/conf/jmxremote.password';
print $jmxpassword "controlRole vmturbo"; # edit 'vmturbo' if you wish to change the default password
close $jmxpassword;

system "chown tomcat /usr/share/tomcat/conf/jmxremote.access";
system "chown tomcat /usr/share/tomcat/conf/jmxremote.password";
system "chmod 600 /usr/share/tomcat/conf/jmxremote.access";
system "chmod 600 /usr/share/tomcat/conf/jmxremote.password";

######################################################################################
print "\n\n\n\nUpdating /etc/my.cnf.d/turbo.cnf bind_address to 0.0.0.0\n\n\n\n\n";
open my $in3, '<', '/etc/my.cnf.d/turbo.cnf' ;
my $content3 = do { undef $/; <$in3> };
close $in3;
my $first_line3 = quotemeta  'bind_address=127.0.0.1';
my $insert3 = 'bind_address=0.0.0.0';


$content3 =~ s/$first_line3/$insert3/g;

open my $out3, '>', '/etc/my.cnf.d/turbo.cnf';
print $out3 $content3;
close $out3;

#############################################################################

print "\n\n\n\nCreating new local and remote SQL user 'sqluser'\n\n\n\n\n";

my $mysqlu = '"CREATE USER ';
my $mysqlu2 = "'sqluser'";
my $mysqlu3 = "@";
my $mysqlu4 = "'turbonomic' ";
my $mysqlu5 = "IDENTIFIED BY 'sqluser'\""; #change this value for local user password
my $mysqlu6 = "'%'";
my $mysqlu7 = " IDENTIFIED BY 'sqlusertbn'\""; #change this value for remote user password

system 'mysql -uroot -pvmturbo -e ' . $mysqlu . $mysqlu2 . $mysqlu3 . $mysqlu4 . $mysqlu5;
system 'mysql -uroot -pvmturbo -e ' . $mysqlu . $mysqlu2 . $mysqlu3 . $mysqlu6 . $mysqlu7;


#######################################################################################################

print "\n\n\n\nGranting SQL user 'sqluser' access to performance_schema DB\n\n\n\n\n";

my $mysqlg = '"GRANT SELECT ON ';
my $mysqlg1 = '"GRANT PROCESS ON ';
my $mysqlg2 = 'performance_schema.* TO ';
my $mysqlg3 = "'sqluser'";
my $mysqlg4 = "@";
my $mysqlg5 = "'turbonomic'\"";
my $mysqlg7 = "'%'\"";
my $mysqlg8 = '*.* TO ';
my $mysqlg9 = '"FLUSH PRIVILEGES"';
#GRANT SELECT ON performance_schema.* TO 'sqluser'@'turbonomic';
system 'mysql -uroot -pvmturbo -e ' . $mysqlg . $mysqlg2 . $mysqlg3 . $mysqlg4 . $mysqlg5;
#GRANT PROCESS ON *.* TO 'sqluser'@'turbonomic'
system 'mysql -uroot -pvmturbo -e ' . $mysqlg1 . $mysqlg8 . $mysqlg3 . $mysqlg4 . $mysqlg5;
#GRANT SELECT ON performance_schema.* TO 'sqluser'@'%'
system 'mysql -uroot -pvmturbo -e ' . $mysqlg . $mysqlg2 . $mysqlg3 . $mysqlg4 . $mysqlg7;
#GRANT PROCESS ON *.* TO 'sqluser'@'%'
system 'mysql -uroot -pvmturbo -e ' . $mysqlg1 . $mysqlg8 . $mysqlg3 . $mysqlg4 . $mysqlg7;
#FLUSH PRIVILEGES;
system 'mysql -uroot -pvmturbo -e ' . $mysqlg9;

#######################################################################################################
print "\n\n\n\nOpening TCP ports for Tomcat JMX (7050 & 7051) and MariaDB (3306)....\n\n\n\n\n";

system "iptables -I INPUT 4 -p tcp --dport 7050 -j ACCEPT";
system "iptables -I INPUT 4 -p tcp --dport 7051 -j ACCEPT";
system "iptables -I INPUT 4 -p tcp --dport 3306 -j ACCEPT";
#######################################################################################
print "\n\n\n\nRestarting tomcat and MariaDB. Please wait....\n\n\n\n\n";


system "service tomcat restart";
system "service mariadb restart";

print "\n\n\n\nAll Done!!! Please add this instance as a Tomcat and/or SQL Target once Turbonomic UI is accessible\n\n\n\n\n";

#####################################################################################################