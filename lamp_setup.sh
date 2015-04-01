#!/bin/bash
#set -x
#
	
# Install or Update needed libs via CentOS command yum
# some of the libs already exist in Install CD/DVD Disk

CUR_DIR=$(pwd)
ISO_IMAGE_PATH=/media/diskd/software/CentOS-6.2-x86_64-bin-DVD1.iso
LOG_FILE=
PHP_LIB_PATH=./libs
LAMP_PATH=/usr/local/lamp
mysql_tar_gz="mysql-5.5.27.tar.gz"
MYSQLDATADIR=/data0/mysql/3306/data
mysqlrootpasswd="123456"
MYSQL_SOCK_LOCATION=${LAMP_PATH}/mysql/mysql.sock
LIBICONV_PACK="libiconv-1.14.tar.gz"
LIBMCRYPT_PACK="libmcrypt-2.5.7.tar.gz"
MHASH_PACK="mhash-0.9.9.9.tar.gz"
MCRYPT_PACK="mcrypt-2.6.8.tar.gz"
PHP_PACK="php-5.3.16.tar.bz2"	#php5.3
MEMCACHE_PACK="memcache-2.2.6.tgz"
EACCELERATOR_PACK="eaccelerator-0.9.6.1.zip"
IMAGEMAGICK_PACK="ImageMagick-6.7.6-5.tar.bz2"
IMAGICK_PACK="imagick-2.3.0.tgz"
ZENDOPTIMIZER_64_PACK="ZendGuardLoader-php-5.3-linux-glibc23-x86_64"   		#for php5.3.x
EACCELERATOR_CACHE_PATH="${LAMP_PATH}/cache/eaccelerator_cache"
PCRE_PACK="pcre-8.30.tar.bz2"
NGINX_PACK="nginx-1.2.0.tar.gz"
PHP_ERROR_LOG="/data0/htdocs/wwwlogs/fpm-php.www.log"
SLOW_BLOG_LOG="/data0/htdocs/wwwlogs/slowlog-blog.log"
NGINX_ROOT_DIR="/data0/htdocs/www"
PHP_WWW_LOGS="/data0/htdocs/wwwlogs"
NGINX_LOG_DIR="/data0/nginx/logs"
PHP_ADMIN_PACK="phpMyAdmin-3.5.4-all-languages.tar.xz"
WORDPRESS_PACK="wordpress-3.4.2.tar.gz"
mysqld_pid_file_path=

#still not used yet
checkCmd(){
	cmd=$1
	oldIFS=$IFS
	IFS=":"
	for dir in $PATH
	do
		if [ -x $dir/${cmd} ];then
			echo 1
			return
		fi
	done
	IFS=$oldIFS
	echo 0
}

adduser(){
	if [[ `grep "www" /etc/passwd` ]] ;then 
		userdel -f www
	fi
	
	if [[ `grep "www" /etc/group` ]];then
		groupdel -f www
	fi
	echo "add user www for web services"


	echo "begin.."
	/usr/sbin/groupadd www
        /usr/sbin/useradd -s /sbin/nologin -g www www
	echo "end.."
}


# Mount ISO images and install enssential libs
install_libs_with_iso_images(){
	#test if ISO Image exists	
	if [ ! -e ${ISO_IMAGE_PATH} ];then
		echo "Can not find ISO Image,"
	fi
	
	#
	if [ ! -d /media/CentOS ];then
		mkdir /media/CentOS
	fi
	
	#mount CentOS Image 
	mount -t iso9660 -o loop ${ISO_IMAGE_PATH} /media/CentOS >./install.log 2>&1
#	echo $*."mount_iso_images"
	lack_libs=""
	for pack in $*;do
#		echo "$pack"
		yum --disablerepo=\* --enablerepo=c6-media -y install $pack >./install.log 2>&1
		
		if [ $? -ne 0 ];then
			lack_libs+=$pack." "	
		fi
		
	done
	
	#if Image ISO doesn't contain enough libs that needed,try 
	# modify 
	yum -y install $lack_libs
	
	if [ $? -ne 0 ];then
		echo "install libs failed!"
	else
		echo "succeed in installing libs"
	fi
}

install_libs_with_yum_repo(){
	echo "Installing using yum ..."| tee -a ${LOG_FILE}
	yum -y install $*
	if [ $? -ne 0 ];then 
		echo "installation with yum Base repo failed!"| tee -a ${LOG_FILE}
		exit 43
	fi
}

install_needed_libs(){
	
	LANG=C
	libstr="gcc gcc-c++ autoconf automake libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel gd gd-devel glibc glibc-devel glib2 glib2-devel bzip2 bzip2-devel ncurses ncurses-devel curl curl-devel e2fsprogs e2fsprogs-devel krb5 krb5-devel libidn libidn-devel openssl-devel ntp nmap nmap-devel"

	echo "Do you want to install libs with Installation ISO image?"
	echo "y/n"
	echo "if you want do install essential libs with ISO image,choose yes,otherwise choose No(default No) "
	read -n 1 if_use_iso
	case ${if_use_iso}
	in
		y|Y)
			install_libs_with_iso_images $libstr # "simple parttern"
			;;

		n|N)
			install_libs_with_yum_repo $libstr
			;;
		*)
			install_libs_with_yum_repo $libstr
			;;
	esac
}


install_nginx(){
	echo "install nginx.."| tee -a ${LOG_FILE}
	
	cd $CUR_DIR/lib
	#pcre
	if test ! -s ".${PCRE_PACK}" ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/pcre-8.30.tar.bz2
	fi

	tar xvf ${PCRE_PACK}

	cd $CUR_DIR

	#if nginx package doesn't exist then download nginx 
        if test ! -s "./${NGINX_PACK}" ;then
               wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/nginx-1.2.0.tar.gz
        fi

	tar xvf ${NGINX_PACK}
	#extract pcre package

	cd ${NGINX_PACK%.tar*.gz}
	
	./configure --user=www --group=www --prefix=${LAMP_PATH}/nginx \
	--with-http_stub_status_module --with-http_ssl_module --with-pcre="$CUR_DIR/lib/${PCRE_PACK%.tar*.bz2}" --with-http_gzip_static_module --with-ipv6
	make && make install
	
	cd ../

	#create Nginx log dir
	if [ ! -d $NGINX_LOG_DIR ];then
		mkdir -p ${NGINX_LOG_DIR}
	fi

	chmod +w ${NGINX_LOG_DIR}
	chown -R www:www ${NGINX_LOG_DIR}

	rm -rf ${LAMP_PATH}/nginx/conf/nginx.conf
	
	cd $CUR_DIR
	if test ! -d conf/ ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/conf.tar.xz
		tar xvf conf.tar.xz
	fi
	cp conf/nginx.conf ${LAMP_PATH}/nginx/conf
	#cp conf/fastcgi.conf ${LAMP_PATH}/nginx/conf

	#system arguments
	cat >/etc/sysctl.conf<<eof
# Add
net.ipv4.tcp_max_syn_backlog = 65536
net.core.netdev_max_backlog =  32768
net.core.somaxconn = 32768

net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2

net.ipv4.tcp_tw_recycle = 1
#net.ipv4.tcp_tw_len = 1
net.ipv4.tcp_tw_reuse = 1

net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_max_orphans = 3276800

#net.ipv4.tcp_fin_timeout = 30
#net.ipv4.tcp_keepalive_time = 120
net.ipv4.ip_local_port_range = 1024  65535

eof

	/sbin/sysctl -p

	#start nginx
	${LAMP_PATH}/nginx/sbin/nginx -c ${LAMP_PATH}/nginx/conf/nginx.conf
			
}

install_php_support_libs(){
	echo "install libs that support php.."| tee -a ${LOG_FILE}
			
	#switch into install directory
	cd $CUR_DIR/lib
	
	# libiconv
	if test ! -s "${LIBICONV_PACK}" ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/libiconv-1.14.tar.gz
	fi
	tar zxvf $LIBICONV_PACK 
	cd ${LIBICONV_PACK%.tar*.gz}
	./configure --prefix=/usr/local
	make
	make install 
	cd ../

	#libmcrypt
	if test ! -s "${LIBMCRYPT_PACK}" ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/libmcrypt-2.5.7.tar.gz
	fi
	tar xvf $LIBMCRYPT_PACK
	cd ${LIBMCRYPT_PACK%.tar*.gz}
	./configure
	make
	make install
	/sbin/ldconfig
	cd libltdl/
	./configure --enable-ltdl-install
	make
	make install
	cd ../..
	
	# mhash
	if test ! -s "${MHASH_PACK}" ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/mhash-0.9.9.9.tar.gz
	fi
	tar zxf $MHASH_PACK
	cd ${MHASH_PACK%.tar*.gz}
	./configure && make && make install
	cd ../
	
	ln -s /usr/local/lib/libmcrypt.la /usr/lib/libmcrypt.la
	ln -s /usr/local/lib/libmcrypt.so /usr/lib/libmcrypt.so
	ln -s /usr/local/lib/libmcrypt.so.4 /usr/lib/libmcrypt.so.4
	ln -s /usr/local/lib/libmcrypt.so.4.4.8 /usr/lib/libmcrypt.so.4.4.8
	ln -s /usr/local/lib/libmhash.a /usr/lib/libmhash.a
	ln -s /usr/local/lib/libmhash.la /usr/lib/libmhash.la
	ln -s /usr/local/lib/libmhash.so /usr/lib/libmhash.so
	ln -s /usr/local//lib/libmhash.so.2 /usr/lib/libmhash.so.2
	ln -s /usr/local/lib/libmhash.so.2.0.1 /usr/lib/libmhash.so.2.0.1

	#mcrypt
	if test ! -s ${MCRYPT_PACK} ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/mcrypt-2.6.8.tar.gz
	fi
	tar zxvf $MCRYPT_PACK
	cd ${MCRYPT_PACK%.tar*.gz}
	/sbin/ldconfig
	./configure && make && make install 
	cd ../..

	#extra lib libjpeg.so libpng.so libmysqlclient.so libiconv.so.2 etc.
	cp -rp /usr/lib64/libjpeg* /usr/lib
	cp -rp /usr/lib64/libpng* /usr/lib
	#cp -rp /usr/lib64/mysql/* /usr/lib/mysql/
	ln -s /usr/local/lib/libiconv.so.2 /usr/lib/libiconv.so.2
	## rm -rf /usr/lib64/mysql   ## no necessary
	#there is no need to do this,if you dont use --with-libdir=lib64,script will only scan */lib directory
	#	
	#ln -s ${LAMP_PATH}/mysql/lib/libmysqlclient.so.18 /usr/lib64/
	#ln -s ${LAMP_PATH}/mysql/lib/libmysqlclient.so.18 /usr/lib64/mysql/
	#in order to make php configure script find openssl lib,but not influence finding mysql libs libmysqlclient.*
	#we have to copy libssl.* from /usr/lib64 to /usr/lib(/usr/${PHP_LIBDIR}),thus mysql lib path would be 
	# ${MYSQL_BASE}/${PHP_LIBDIR} (/usr/local/lamp/mysql/lib).
	cp -rp /usr/lib64/libssl.* /usr/lib 
}

install_php(){
	#configre error notifice to reinstall the libcurl distribution
	
	#MySQL as a server works fine but mysql_config returns -lprobes_mysql which does not exist
	#see details from http://bugs.mysql.com/bug.php?id=60948 this bug doesn't appear in some other environment
	sed -i 's/libs=" $ldflags -L$pkglibdir -lmysqlclient   -lpthread -lprobes_mysql -lz -lm -lrt -ldl "/libs=" $ldflags -L$pkglibdir -lmysqlclient   -lpthread -lz -lm -lrt -ldl "/g'	 ${LAMP_PATH}/mysql/bin/mysql_config

	cd $CUR_DIR
	if test ! -s "${PHP_PACK}" ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/php-5.3.16.tar.bz2
	fi
	echo "install php.."| tee -a ${LOG_FILE}
	tar xvf ${PHP_PACK}
	cd ${PHP_PACK%.tar*bz2}

	./configure --prefix=${LAMP_PATH}/php \
	--with-config-file-path=${LAMP_PATH}/php/etc \
	--with-mysql=${LAMP_PATH}/mysql \
	--with-mysqli=/${LAMP_PATH}/mysql/bin/mysql_config \
	--with-pdo-mysql=${LAMP_PATH}/mysql \
	--with-mysql-sock=${LAMP_PATH}/mysql/mysql.sock \
	--with-iconv-dir=/usr/local \
	--enable-fpm  \
	--with-fpm-user=www \
	--with-fpm-group=www \
	--disable-phar \
	--with-pcre-regex \
	--with-zlib \
	--with-bz2 \
	--enable-calendar \
	--with-curl \
	--enable-dba \
	--with-libxml-dir \
	--enable-ftp \
	--with-gd \
	--with-jpeg-dir \
	--with-png-dir \
	--with-zlib-dir \
	--with-freetype-dir \
	--enable-gd-native-ttf \
	--enable-gd-jis-conv \
	--with-mhash \
	--enable-mbstring \
	--with-mcrypt  \
	--enable-pcntl \
	--enable-xml \
	--disable-rpath  \
	--enable-shmop \
	--enable-sockets \
	--enable-zip \
	--enable-bcmath \
	--enable-soap \
	--with-openssl \
	--with-curl 
	
#	--with-snmp \
#	--disable-ipv6 \

	make ZEND_EXTRA_LIBS='-liconv'
	make install
	
	mkdir -p ${LAMP_PATH}/php/etc/
	cp php.ini-production ${LAMP_PATH}/php/etc/php.ini
	cd ../
	

	if test -s /usr/bin/php ;then
		mv /usr/bin/php /usr/bin/php.old
	fi
	
	if test -s /usr/bin/php-cgi ;then
		mv /usr/bin/php-cgi /usr/bin/php-cgi.old
	fi
	
	ln -s ${LAMP_PATH}/php/bin/php /usr/bin/php
	ln -s ${LAMP_PATH}/php/bin/phpize /usr/bin/phpize
	ln -s ${LAMP_PATH}/php/sbin/php-fpm /usr/bin/php-fpm

	cd $CUR_DIR/lib/
	if test ! -s "${MEMCACHE_PACK}" ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/memcache-2.2.6.tgz
	fi
	tar zxvf ${MEMCACHE_PACK}
	cd ${MEMCACHE_PACK%.tgz}
	${LAMP_PATH}/php/bin/phpize
	./configure --with-php-config=${LAMP_PATH}/php/bin/php-config
	make && make install 
	
	cd $CUR_DIR/lib/
	if test ! -s "${EACCELERATOR_PACK}" ;then
                wget -nc -c --progress=bar:force  http://auto-blog-setup.googlecode.com/files/eaccelerator-0.9.6.1.zip 
        fi
	unzip -o ${EACCELERATOR_PACK}
	cd ${EACCELERATOR_PACK%.zip}
	${LAMP_PATH}/php/bin/phpize
	./configure --enable-eaccelerator=shared --with-php-config=${LAMP_PATH}/php/bin/php-config
	make && make install
	cd ..

	cd $CUR_DIR/lib
	if test ! -s "${IMAGEMAGICK_PACK}" ;then
                wget -nc -c --progress=bar:force -O ${IMAGEMAGICK_PACK} http://auto-blog-setup.googlecode.com/files/ImageMagick-6.7.6-5.tar.bz2
        fi
	tar xvf ${IMAGEMAGICK_PACK}
	cd ${IMAGEMAGICK_PACK%.tar*.bz2}
	./configure && make && make install
	cd ../

	cd $CUR_DIR/lib
	if test ! -s "${IMAGICK_PACK}" ;then
                wget -nc -c --progress=bar:force  http://auto-blog-setup.googlecode.com/files/imagick-2.3.0.tgz
        fi
	tar xvf ${IMAGICK_PACK}
	cd ${IMAGICK_PACK%.tgz}
	${LAMP_PATH}/php/bin/phpize
	./configure --with-php-config=${LAMP_PATH}/php/bin/php-config
	make && make install
	cd ../
	

	#back up the php config first
	cp ${LAMP_PATH}/php/etc/php.ini ${LAMP_PATH}/php/etc/php.ini.bak	
	#then modify php.ini
	sed -i 's#; extension_dir = "./"#extension_dir = "/usr/local/lamp/php/lib/php/extensions/no-debug-non-zts-20090626/"\n\nextension = "memcache.so"\nextension = "imagick.so"\n#' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's#output_buffering = Off#output_buffering = On#' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's/post_max_size = 8M/post_max_size = 50M/g' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 50M/g' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's/;date.timezone =/date.timezone = PRC/g' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's/short_open_tag = Off/short_open_tag = On/g' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's/; cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's/; cgi.fix_pathinfo=0/cgi.fix_pathinfo=0/g' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's/max_execution_time = 30/max_execution_time = 300/g' ${LAMP_PATH}/php/etc/php.ini
	sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,scandir,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_alter,ini_restore,dl,pfsockopen,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server,fsocket,fsockopen/g' ${LAMP_PATH}/php/etc/php.ini
	sed -i "s#;always_polulate_raw_post_data = On#always_populate_raw_post_data = On#g" ${LAMP_PATH}/php/etc/php.ini
	
	#create cache dir
	mkdir -p ${LAMP_PATH}/cache/eaccelerator_cache
	chmod 0777 ${LAMP_PATH}/cache/eaccelerator_cache
	#add eaccelerator 
	cat>>${LAMP_PATH}/php/etc/php.ini<<eof
;eaccelerator added by lvfeng
[eaccelerator]
zend_extension="${LAMP_PATH}/php/lib/php/extensions/no-debug-non-zts-20090626/eaccelerator.so"
eaccelerator.shm_size="1"
eaccelerator.cache_dir="${EACCELERATOR_CACHE_PATH}"
eaccelerator.enable="1"
eaccelerator.optimizer="1"
eaccelerator.check_mtime="1"
eaccelerator.debug="0"
eaccelerator.filter=""
eaccelerator.shm_max="0"
eaccelerator.shm_ttl="0"
eaccelerator.shm_prune_period="0"
eaccelerator.shm_only="0"
eaccelerator.compress="1"
eaccelerator.compress_level="9"	
eof
	cd $CUR_DIR/lib
	if [ `getconf WORD_BIT` = '32' ] && [ `getconf LONG_BIT` = '64' ];then
                if test ! -s "$CUR_DIR/lib/${ZENDOPTIMIZER_64_PACK}.tar.gz" ;then
		wget -nc -c --progress=bar:force  http://auto-blog-setup.googlecode.com/files/ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz
                fi
                tar zxvf ${ZENDOPTIMIZER_64_PACK}.tar.gz
		mkdir -p ${LAMP_PATH}/zend
		cp $CUR_DIR/lib/${ZENDOPTIMIZER_64_PACK}/php-5.3.x/ZendGuardLoader.so ${LAMP_PATH}/zend -f
	
        else
		
                echo "do not support 32bit yet!"
	
        fi
	#add Zend Optimizer to php.ini

	cat >>${LAMP_PATH}/php/etc/php.ini <<EOF
;add Zend Optimizer to php.ini
[Zend Optimizer] 
zend_optimizer.optimization_level=1 
zend_extension="${LAMP_PATH}/zend/ZendGuardLoader.so" 
EOF


	mkdir -p ${NGINX_ROOT_DIR}
	chmod +w ${NGINX_ROOT_DIR}
	chown -R www:www ${NGINX_ROOT_DIR}
	mkdir -p ${PHP_WWW_LOGS}
	chmod +w ${PHP_WWW_LOGS}
	chown -R www:www ${PHP_WWW_LOGS}


	#rm -f ${LAMP_PATH}/php/etc/php-fpm.conf
	cp ${LAMP_PATH}/php/etc/php-fpm.conf.default ${LAMP_PATH}/php/etc/php-fpm.conf

	php_config_file=${LAMP_PATH}/php/etc/php-fpm.conf

	#echo "if you want to squeeze all the juice out of your VPS or web server / servers and do your maintenance work little bit easier?(y/n default yes)"
	#This is normally excellent start and all pool configs go to /etc/php-fpm.d directory.
	# "*" need \*
	sed -i 's#;include=etc/fpm.d/\*.conf#include=etc/php-fpm.d/\*.conf#g' $php_config_file
	# few globe settings
	sed -i "s#;pid = run/php-fpm.pid#pid = run/php-fpm.pid#g" $php_config_file

	sed -i "s#;error_log = log/php-fpm.log#error_log = log/php-fpm.log#g" $php_config_file

	sed -i "s#;log_level = notice#log_level = notice#g" $php_config_file

	sed -i "s#;emergency_restart_threshold = 0#emergency_restart_threshold = 10#g" $php_config_file

	sed -i "s#;emergency_restart_interval = 0#emergency_restart_interval = 1m#g" $php_config_file

	sed -i "s#;process_control_timeout = 0#process_control_timeout = 10s#g" $php_config_file
	
	sed -i "s#;php_flag[display_errors] = off#php_flag[display_errors] = on#g" $php_config_file

	sed -i "s#;php_admin_value[error_log] = /var/log/fpm-php.www.log#php_admin_value[error_log] = ${PHP_ERROR_LOG}#g" $php_config_file

	if test ! -d ${LAMP_PATH}/php/etc/php-fpm.d ;then
		mkdir -p ${LAMP_PATH}/php/etc/php-fpm.d
	fi
	
	if test ! -d ${LAMP_PATH}/php/logs ;then
		mkdir -p ${LAMP_PATH}/php/logs
	fi

	#load a new configurations for pool blog
cat>${LAMP_PATH}/php/etc/php-fpm.d/blog.conf<<EOF
[blog]
listen = 127.0.0.1:9001
user = www
group = www
request_slowlog_timeout = 5s
slowlog = ${SLOW_BLOG_LOG}
listen.allowed_clients = 127.0.0.1
pm = dynamic
pm.max_children = 4
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 200
listen.backlog = -1
pm.status_path = /status
request_terminate_timeout = 120s
rlimit_files = 131072
rlimit_core = unlimited
catch_workers_output = yes
env[HOSTNAME] = $HOSTNAME
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
EOF

	#start php-cgi
	ulimit -SHn 65535
	${LAMP_PATH}/php/sbin/php-fpm -R

}

install_mysql(){
	echo "install mysql right now"| tee -a ${LOG_FILE}
	if [[ `grep "mysql" /etc/passwd` && `grep "mysql" /etc/group` ]];then
		echo "user mysql already exists"
		echo "keep current user (y) or delete it and create new one (n)"
		read -n 1 createOrdelete
		case $createOrdelete
		in
			y|Y )
			 break
			;;
			n|N)
				/usr/sbin/userdel -rf mysql >/dev/null
				/usr/sbin/groupdel mysql >/dev/null
				/usr/sbin/groupadd mysql
				/usr/sbin/useradd -g mysql mysql
			;;
			*)
			break
			;;
		esac
	else 
		#simplely recreate mysql user and group
		/usr/sbin/userdel -rf mysql >/dev/null
		/usr/sbin/groupdel mysql >/dev/null
		/usr/sbin/groupadd mysql
		/usr/sbin/useradd -g mysql mysql
	fi

	#if mysql source package does not exist then download it
	if test ! -e "${mysql_tar_gz}" ;then
		wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/mysql-5.5.27.tar.gz 
	fi
	#extract mysql tar.gz package
	tar xvf ${mysql_tar_gz} 
	cd ${mysql_tar_gz%.tar*gz}
	
	#The CMake program provides a great deal of control over how you configure a MySQL source distribution. 
	cmake . \
	-DCMAKE_INSTALL_PREFIX=${LAMP_PATH}/mysql/ \
	-DCOMPILATION_COMMENT=CentOS6.3 \
	-DDEFAULT_CHARSET=utf8 \
	-DDEFAULT_COLLATION=utf8_general_ci \
	-DENABLED_LOCAL_INFILE=ON
	-DWITH_INNOBASE_STORAGE_ENGINE=1 \
	-DMYSQL_TCP_PORT=3306 \
	-DEXTRA_CHARSETS=all \
	-DMYSQL_UNIX_ADDR=${MYSQL_SOCK_LOCATION} \
	-DMYSQL_USER=mysql \
	-DWITH_DEBUG=0 \
	-DMYSQL_DATADIR=/data0/mysql/3306/data \
	-DWITH_READLINE=ON \
	-DENABLE_DTRACE=OFF \
	
	make && make install
	chmod +w ${LAMP_PATH}/mysql
	chown -R mysql:mysql ${LAMP_PATH}/mysql
		
	# 1)create MySQL database store directory
	if [ ! -d ${MYSQLDATADIR} ];then
		mkdir -p ${MYSQLDATADIR}
	fi
	chown -R mysql:mysql /data0/mysql/
	
	# mysql config file
	cp support-files/my-medium.cnf /etc/my.cnf
	#modify the socket location 
	sed -i s#/tmp/mysql.sock#${MYSQL_SOCK_LOCATION}#g /etc/my.cnf
	
	# mysql start script
	cp support-files/mysql.server /etc/init.d/mysqld
	sed -i "s#^basedir=.*#&${LAMP_PATH}/mysql#" /etc/init.d/mysqld
	sed -i "s#^datadir=.*#&${MYSQLDATADIR}#" /etc/init.d/mysqld
	#sed -i "s#^mysqld_pid_file_path=.*#&${MYSQLDATADIR}#" /etc/init.d/mysqld
	chmod 755 /etc/init.d/mysqld
	
	chkconfig --add mysqld
	chkconfig --level 345  mysqld on
	
	ln -s ${LAMP_PATH}/mysql/lib/mysql /usr/lib/mysql
	ln -s ${LAMP_PATH}/mysql/include/mysql /usr/include/mysql
	cat > /etc/ld.so.conf.d/mysql.conf<<EOF
${LAMP_PATH}/mysql/lib/mysql
${LAMP_PATH}/mysql/lib
EOF
	ldconfig
	
	#  Create database with Account mysql
	${LAMP_PATH}/mysql/scripts/mysql_install_db --basedir=${LAMP_PATH}/mysql \
	--datadir=${MYSQLDATADIR} \
	--user=mysql
	
	echo "starting mysql.."
        ${LAMP_PATH}/mysql/bin/mysqld_safe --user=mysql --datadir=${MYSQLDATADIR} &  >/dev/null 2>&1

        sleep 10
        pid=`ps aux | grep mysqld | sed -n '2P' | awk '{print $2}'`
        while true ;do

                if [ -z $pid ];then
                        sleep 10
                        pid=`ps aux | grep mysqld | sed -n '2P' | awk '{print $2}'`
                else 
			break
                fi
        done

	#set the password  
	${LAMP_PATH}/mysql/bin/mysqladmin -u root password $mysqlrootpasswd
	cat > /tmp/mysql_sec_script<<EOF
use mysql;
update user set password=password('$mysqlrootpasswd') where user='root';
delete from user where not (user='root') ;
delete from user where user='root' and password=''; 
drop database test;
DROP USER ''@'%';
flush privileges;
EOF

${LAMP_PATH}/mysql/bin/mysql -u root -p$mysqlrootpasswd -h localhost < /tmp/mysql_sec_script

	#kill mysqld service 
#	ps -ef |grep mysqld |grep -v grep|grep -v mysqld_safe |awk -F" " '{print $2}' | xargs -i kill {} >/dev/null 2>&1
#	/etc/init.d/mysqld stop
		
	#add mysql envirenment to PATH var
	PATH=$PATH:${LAMP_PATH}/mysql/bin:
	export PATH
}

#install wordpress
install_wordpress(){
	echo "install wordpress..."
	cd $CUR_DIR/lib
	if test ! -e "${WORDPRESS_PACK}" ;then
		wget -nc -c --progress=bar:force  http://cn.wordpress.org/wordpress-3.4.2-zh_CN.tar.gz
	fi
	tar xvf $WORDPRESS_PACK
	cp wordpress/* /data0/htdocs/www -rf
	
	#initialize the worepress destination database,and prepare for installaion
	cat > /tmp/create_wp_db<<EOF


EOF

	#initialize mysqld pid file path 
	if test -z "$mysqld_pid_file_path"
	then
		mysqld_pid_file_path=${MYSQLDATADIR}/`hostname`.pid
	else
		case "mysqld_pid_file_path" in
		/* ) ;;
		* ) mysqld_pid_file_path="${MYSQLDATADIR}/$mysqld_pid_file_path" ;;
		esac
	fi ##end of test mysql pid file path

	if test -s "$mysqld_pid_file_path";then
		read mysqld_pid < "$mysqld_pid_file_path"
		if (kill -0 $mysqld_pid 2>/dev/null)
		then
			echo ""
			#load the wordpress database 
cat>/tmp/create_db_script <<EOF
CREATE DATABASE wordpress;
--GRANT ALL PRIVILEGES ON wordpress.* TO "wordpress"@spawn-laptop" IDENTIFIED BY "password";
create user 'wordpress'@'spawn-laptop' identified by 'wordpress';
grand all privileges on wordpress.* to 'wordpress'@'spawn-laptop';
flush privileges;
EOF
			mysql -uroot -p$mysqlrootpasswd 
		else 
			echo "MySQL Sever is not runing.."
			echo "start mysqld..."
			/etc/init.d/mysqld start
				
		fi
	fi
}


#phpadmin
install_phpadmin(){
	if test ! -d ${NGINX_ROOT_DIR}/phpadmin/config/config.inc.php ;then
		echo "install phpAdmin..."
		cd $CUR_DIR/lib
		if test ! -e "${PHP_ADMIN_PACK}" ;then
			wget -nc -c --progress=bar:force http://auto-blog-setup.googlecode.com/files/phpMyAdmin-3.5.4-all-languages.tar.xz
		fi
		tar xvf ${PHP_ADMIN_PACK}
		cp ${PHP_ADMIN_PACK%.tar*bz2} ${NGINX_ROOT_DIR}/phpadmin -rf
		chown www:www ${NGINX_ROOT_DIR}/phpadmin
		cd ${NGINX_ROOT_DIR}/phpadmin
		mkdir config
		chmod o+rw config
		cp $CUR_DIR/conf/config.inc.php config/
		chmod o+w config/config.inc.php
		echo "now open http://127.0.0.1/phpMyAdmin/setup/ in your browser,Changes are saved to disk until you explicitly chooose Save from the Configuraion area of screen."
		echo "then restart the script choose only install phpadmin part to remove config.inc.php file"
	else
		echo "have you already save the changes?(y/n)"
		read issave
		case $issave
		in
		        y|Y)
				cd ${NGINX_ROOT_DIR}/phpadmin
				mv config/config.inc.php .
				chmod o-rw config.inc.php
				;;
			n|N)
				echo "now open http://127.0.0.1/phpMyAdmin/setup/ in your browser,Changes are saved to disk until you explicitly chooose Save from the Configuraion area of screen."
				;;
			*)	;;
		esac
	fi
}

toggle_var(){
	# if variable passed an argument equals to $value1 set it to $value2
	#otherwise set it to $value1
	value1=' '
	value2='*'
	var=\$"$1"
	##value=`eval "expr \"$var\""`
	eval value=\$$1
	if [ "x$value" = "x$value1" ];then
		eval "$1=$value2"
	else
		eval "$1=\"$value1\""
	fi
}



menu(){
	INSTALL_NGINX='*'
	ENABLE_EPEL_REPO=' '
	INSTALL_PHP='*'
	INSTALL_MYSQL='*'
	INSTALL_WORDPRESS=' '
	INSTALL_LACK_LIBS=' '
	INSTALL_PHPADMIN=' '
	while true;do
		
		clear
		echo "Choose what you want to install and setup:"
		echo "Selected items marked by '*'"
		echo 

		echo "1. $INSTALL_NGINX install nginx"
		echo "2. $INSTALL_PHP Configure PHP,install and configure php-fpm"
		echo "3. $INSTALL_MYSQL Install and configure MySQL"
		echo "4. $INSTALL_LACK_LIBS Install essential libs used to compile MySQL,PHP,Nginx"
		echo "5. $INSTALL_WORDPRESS Install and Configure wordpress"
		echo "6. $INSTALL_PHPADMIN Install phpadmin(web console for MySQL)"
		echo "7.   Exit"
		echo "0.   Continue"
		echo 
		read -s -n 1 CHOICE
		case $CHOICE
		in
			1)	toggle_var INSTALL_NGINX
				;;
			2)	toggle_var INSTALL_PHP
				;;
			3)	toggle_var INSTALL_MYSQL
				;;
			4)	toggle_var INSTALL_LACK_LIBS
				;;
			5)	toggle_var INSTALL_WORDPRESS
				;;
			
			6)	toggle_var INSTALL_PHPADMIN
				;;
			7)	echo "Exiting"
				exit 0
				;;
			0) 	break
				;;
			*)	;;
		esac
	done
}

#check all the packages which was used to compile and install lnmp
check_all_pkgs(){
	echo ""
}


#check root privilege
am_i_root(){
	USERID=`id -u`
	if [ 0 -ne $USERID ];then
		echo "This script require root privileges to run,exiting"
		exit 1
	fi
}

am_i_root
menu

echo "Install Progress Begining here.."

#create lamp directory 
if [ ! -d ${LAMP_PATH} ];then
	mkdir -p ${LAMP_PATH}
fi
#if doesn't exist lib directory then
if [ ! -d "${CUR_DIR}/lib" ];then
	mkdir ${CUR_DIR}/lib
fi

if [ x$INSTALL_LACK_LIBS = 'x*' ];then
install_needed_libs
fi

if [ x$INSTALL_MYSQL = 'x*' ];then
install_mysql
fi

if [ x$INSTALL_PHP = 'x*' ];then
install_php_support_libs
adduser
install_php
fi

if [ x$INSTALL_NGINX = 'x*' ];then
install_nginx
fi

if [ x$INSTALL_WORDPRESS = 'x*' ];then
install_wordpress
fi

if [ x$INSTALL_PHPADMIN = 'x*' ];then
install_phpadmin
fi

exit 0
