#!/bin/bash
PCRE_version=8.43
ZLIB_version=1.2.11
OPENSSL_version=1.1.1c
NGINX_version=1.16.1
nginxDir=/opt/nginx
nginxAF=/etc/nginx/conf.d
nginxLogDir=/var/log/nginx
function preRequirements() {
    # yum -y update
    yum -y install wget
    yum group install "Development Tools" -y
    yum install libxml2-devel libxslt-devel gd-devel  perl-ExtUtils-Embed  GeoIP-devel gperftools -y
    if [ ! -d $nginxDir ]; then
        mkdir -p $nginxDir
    fi
    if [ ! -d $nginxLogDir ]; then
        mkdir -p $nginxLogDir
    fi
    if [ ! -d $nginxAF ]; then
        mkdir -p $nginxAF
    fi
    cd $nginxDir
}
function installPCRE() {
                cd pcre-$PCRE_version  && \
                ./configure && \
                make && \
                make install
    cd $nginxDir
    
}
function downloadPCRE(){
    cd $nginxDir
    wget https://ftp.pcre.org/pub/pcre/pcre-$PCRE_version.tar.gz && \
    tar -zxf pcre-$PCRE_version.tar.gz
    rm -rf pcre-$PCRE_version.tar.gz
}
function downloadZlib(){
    cd $nginxDir
    wget http://zlib.net/zlib-$ZLIB_version.tar.gz && \
    tar -zxf zlib-$ZLIB_version.tar.gz
    rm -rf zlib-$ZLIB_version.tar.gz 
}
function installZlib() {
                cd zlib-$ZLIB_version && \
                ./configure && \
                make && \
                make install
    cd $nginxDir
    
}

function installOpenSSL() {
    wget http://www.openssl.org/source/openssl-$OPENSSL_version.tar.gz && \
                tar -zxf openssl-$OPENSSL_version.tar.gz && \
                cd openssl-$OPENSSL_version && \
                ./Configure linux-x86_64 --prefix=/usr && \
                make && \
                make install
    cd $nginxDir
    rm -rf openssl-$OPENSSL_version.tar.gz
}
function installNginx_brotli {
    if [ ! -d "$nginxDir/ngx_brotli" ]; then
        git clone https://github.com/google/ngx_brotli
        cd ngx_brotli
        git submodule update --init
        cd $nginxDir
    fi
}
function installNginx_SH {
    if [ ! -d "$nginxDir/ngx_security_headers" ]; then
        git clone https://github.com/GetPageSpeed/ngx_security_headers
        cd $nginxDir
    fi

}
function downloadnginx(){
    cd $nginxDir
    wget https://nginx.org/download/nginx-$NGINX_version.tar.gz
    tar zxf nginx-$NGINX_version.tar.gz
    rm -rf nginx-$NGINX_version.tar.gz
}
function installNginx() {
                cd nginx-$NGINX_version && \
                ./configure --prefix=/usr/share/nginx --sbin-path=/usr/local/nginx/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-stream_ssl_preread_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-http_auth_request_module --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -m64 -mtune=generic' --with-ld-opt='-Wl,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E' --add-dynamic-module=../ngx_brotli --add-dynamic-module=../ngx_security_headers
                make  && \
                make install          
}
function createNginxUser() {
    useradd nginx --shell=/sbin/nologin --home-dir=/var/cache/nginx
}
function createnginxService() {
    cat > /usr/lib/systemd/system/nginx.service <<EOF
    [Unit]
    Description=nginx - high performance web server
    Documentation=http://nginx.org/en/docs/
    After=network-online.target remote-fs.target nss-lookup.target
    Wants=network-online.target

    [Service]
    Type=forking
    PIDFile=/var/run/nginx.pid
    ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf
    ExecReload=/bin/sh -c "/bin/kill -s HUP \$(/bin/cat /var/run/nginx.pid)"
    ExecStop=/bin/sh -c "/bin/kill -s TERM \$(/bin/cat /var/run/nginx.pid)"

    [Install]
    WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}
function createnginxConfig() {
    rm -rf /etc/nginx/nginx.conf
    cat >  /etc/nginx/nginx.conf <<EOF
user  nginx;
worker_processes  auto;
load_module /usr/lib64/nginx/modules/ngx_http_security_headers_module.so;
load_module /usr/lib64/nginx/modules/ngx_http_brotli_filter_module.so;
load_module /usr/lib64/nginx/modules/ngx_http_brotli_static_module.so;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  4096;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  65;
    brotli on;
    brotli_comp_level 6;
    brotli_static on;
    brotli_types        text/xml image/svg+xml application/x-font-ttf image/vnd.microsoft.icon application/x-font-opentype application/json font/eot application/vnd.ms-fontobject application/javascript font/otf application/xml application/xhtml+xml text/javascript  application/x-javascript text/plain application/x-font-truetype application/xml+rss image/x-icon font/opentype text/css image/x-win-bitmap;
    include /etc/nginx/conf.d/*.conf;
}
EOF

}

preRequirements
if [ ! -d "$nginxDir/pcre-$PCRE_version" ]; then
    downloadPCRE
    if [ ! -d "/usr/local/share/doc/pcre" ]; then
    echo "Install PCRE"
    installPCRE
    fi
fi
if [ ! -d "/usr/share/doc/openssl" ]; then
    echo "Install OpenSSL"
    installOpenSSL
fi
find / -name zlib | grep 'pstore/zlib'  >> /dev/null 2>&1
if [ ! -d "$nginxDir/zlib-$ZLIB_version" ]; then
    downloadZlib
    if [ $? -ne 0 ]; then
        echo "Install Zlib"
        installZlib
    fi
fi
echo "Install nginx_brotli module"
installNginx_brotli
echo "Install ngx_security_headers module"
installNginx_SH
if [ ! -d "$nginxDir/nginx-$NGINX_version" ]; then
    downloadnginx
fi
echo "Install Nginx"
installNginx
netstat -nltp | grep nginx >> /dev/null 2>&1
if [ $? -ne 0 ]; then
    createNginxUser
    createnginxService
    createnginxConfig
else
    echo OK
fi

