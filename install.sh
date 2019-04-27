#!/bin/bash

set -o -x

test -f /usr/bin/yum     && yum install -y git libatomic_ops-devel jemalloc-devel openssl-devel unzip pcre-devel pcre2-devel GeoIP-devel
test -f /usr/bin/apt-get &&  apt-get update
test -f /usr/bin/apt-get &&  apt-get install -y git libgeoip-dev libatomic-ops-dev libjemalloc-dev libssl-dev unzip build-essential libpcre3-dev xz-utils perl zlib1g-dev

TENGINE=tengine-20190408
OPENRESTY=openresty-1.15.8.1rc1
NGX_TCP_MODULE=nginx_tcp_proxy_module-20180401
NGX_VTS=nginx-module-vts-20180722
OPENSSL=openssl-1.1.1
PREFIX_TENGINE=/app/nginx
PREFIX_LUAJIT=$PREFIX_TENGINE/luajit
LOG_DIR=/app/logs/nginx/
NGX_HC=ngx_healthcheck_module-20190322
LUAJIT=luajit2-20190328

cd $(dirname $0)
basedir=$(pwd)

mkdir -p ${PREFIX_TENGINE}/{html,temp,logs,modules,dso} $LOG_DIR
chown nobody:nobody -R ${PREFIX_TENGINE}/temp  $LOG_DIR

rm -rf build/*
mkdir -p bundle build

cd $basedir/bundle
test -f $OPENRESTY.tar.gz || wget -c https://openresty.org/download/$OPENRESTY.tar.gz

COMMITID=d1dd875
GIRURL=https://github.com/alibaba/tengine.git
GITDIR=tengine-master 
cd $basedir/bundle
test -f $TENGINE.zip || test -d $GITDIR || git clone $GIRURL $GITDIR
cd $GITDIR
git fetch
git checkout $COMMITID

COMMITID=46d8555
GIRURL=https://github.com/vozlt/nginx-module-vts.git
GITDIR=nginx-module-vts-master
cd $basedir/bundle
test -f $NGX_VTS.zip || test -d $GITDIR || git clone $GIRURL $GITDIR
cd $GITDIR
git fetch
git checkout $COMMITID


COMMITID=d4272c8
GIRURL=https://github.com/zhouchangxun/ngx_healthcheck_module.git
GITDIR=ngx_healthcheck_module-master
cd $basedir/bundle
test -f $NGX_HC.zip  || test -d $GITDIR || git clone $GIRURL $GITDIR
cd $GITDIR
git fetch
git checkout $COMMITID


#cp -r bundle/$TENGINE.zip build
#cp -r bundle/$NGX_TCP_MODULE.zip build
#cp -r bundle/$OPENRESTY.tar.gz build
#cp -r bundle/$NGX_VTS.zip build
#cp -t build -r bundle/$NGX_HC.zip  bundle/$LUAJIT.zip
cd $basedir
cp -t build -r bundle/$TENGINE.zip bundle/$OPENRESTY.tar.gz bundle/$NGX_VTS.zip bundle/$NGX_HC.zip bundle/*-master

cd build
workdir=$(pwd)

cd $workdir

ls *.tar.gz | xargs -t -i tar zxf {}
ls *.zip |xargs -t -i unzip -uoq {}


install_luajit(){
echo $PREFIX_LUAJIT/bin/luajit not found, install now.
cd $workdir/${OPENRESTY}/bundle/LuaJIT-*
#cd  $workdir/luajit2-*
# sed -i "s/^export PREFIX=.*$/export PREFIX= \/app\/nginx\/luajit/g" Makefile
sed -i 's/^export PREFIX=.*$//g' Makefile
sed -i 1"i\export PREFIX=$PREFIX_LUAJIT" Makefile
make clean
make -j4
make install
echo "[ok] install luajit: $PREFIX_LUAJIT"
}

test -f $PREFIX_LUAJIT/bin/luajit-2.1.0-beta3 || install_luajit

cd $workdir/tengine-master

test -f .ngxhc.patched || ( git apply ../ngx_healthcheck_module-master/nginx_healthcheck_for_tengine_2.3+.patch && touch .ngxhc.patched )
test -f .ngxhc.patched || ( patch -p1 < ../ngx_healthcheck_module-master/nginx_healthcheck_for_tengine_2.3+.patch && touch .ngxhc.patched )

export LUAJIT_LIB=$PREFIX_LUAJIT/lib
export LUAJIT_INC=$PREFIX_LUAJIT/include/luajit-2.1
export LUA_INCLUDE_DIR=$PREFIX_LUAJIT/include/luajit-2.1

./configure --prefix=$PREFIX_TENGINE \
--with-http_ssl_module --with-http_v2_module \
--with-libatomic --with-jemalloc \
--with-luajit-inc=$PREFIX_LUAJIT/include/luajit-2.1 \
--with-luajit-lib=$PREFIX_LUAJIT/lib \
--with-lua-inc=$PREFIX_LUAJIT/include/luajit-2.1 \
--with-lua-lib=$PREFIX_LUAJIT/lib \
--with-ld-opt=-Wl,-rpath,$PREFIX_LUAJIT/lib  \
--with-pcre-jit --with-pcre \
--sbin-path=$PREFIX_TENGINE/sbin/nginx \
--conf-path=$PREFIX_TENGINE/conf/nginx.conf \
--http-log-path=${LOG_DIR}/access.log \
--error-log-path=${LOG_DIR}/error.log \
--with-http_gzip_static_module --with-http_stub_status_module \
--with-http_secure_link_module  --with-file-aio  --with-http_realip_module \
--with-http_addition_module --with-http_sub_module  --with-http_gunzip_module \
--with-http_auth_request_module --with-http_random_index_module \
--with-http_degradation_module \
--pid-path=/var/run/nginx.pid \
--http-client-body-temp-path=$PREFIX_TENGINE/temp/client_body_temp \
--http-proxy-temp-path=$PREFIX_TENGINE/temp/proxy_temp \
--http-fastcgi-temp-path=$PREFIX_TENGINE/temp/fastcgi_temp \
--http-uwsgi-temp-path=$PREFIX_TENGINE/temp/uwsgi_temp \
--http-scgi-temp-path=$PREFIX_TENGINE/temp/scgi_temp \
--add-module=../${OPENRESTY}/bundle/ngx_devel_kit-* \
--add-module=../${OPENRESTY}/bundle/echo-nginx-module-* \
--add-module=../${OPENRESTY}/bundle/headers-more-nginx-module-* \
--add-module=../${OPENRESTY}/bundle/encrypted-session-nginx-module-* \
--add-module=../${OPENRESTY}/bundle/set-misc-nginx-module-* \
--add-module=../${OPENRESTY}/bundle/form-input-nginx-module-* \
--add-module=../nginx-module-vts-master \
--add-module=../${OPENRESTY}/bundle/ngx_lua-* \
--add-module=modules/ngx_http_concat_module \
--add-module=modules/ngx_http_footer_filter_module \
--add-module=modules/ngx_http_reqstat_module \
--add-module=modules/ngx_http_slice_module \
--add-module=modules/ngx_http_trim_filter_module \
--add-module=modules/ngx_http_upstream_consistent_hash_module \
--add-module=modules/ngx_http_upstream_dynamic_module \
--add-module=modules/ngx_http_upstream_session_sticky_module \
--add-module=modules/ngx_http_user_agent_module \
--with-stream \
--with-stream_ssl_module \
--with-stream_realip_module \
--with-stream_geoip_module \
--add-module=../ngx_healthcheck_module-master \


## 1.15 disable
## --add-module=modules/ngx_http_upstream_check_module \

#--with-http_lua_module \

sed -i '/^CFLAGS/ s/$/ -Wno-implicit-fallthrough /' objs/Makefile
make -j8
#make CFLAGS='-Wno-error=implicit-fallthrough' -j8
cp $PREFIX_TENGINE/sbin/nginx $PREFIX_TENGINE/sbin/nginx.bak.`date "+%Y%m%d%H%M%S"` && echo "[ok] backup old  tengine"

make install && echo "[ok] install new  tengine"
cp $PREFIX_TENGINE/sbin/nginx $PREFIX_TENGINE/sbin/nginx.org.`date "+%Y%m%d%H%M%S"` && echo "[ok] backup new  tengine"
strip $PREFIX_TENGINE/sbin/* && echo "[ok] strip new tengine"

#cd $workdir/$NGX_VTS &&  $PREFIX_TENGINE/sbin/dso_tool -a=`pwd` -d=/app/nginx/modules && echo "[ok] install vts module"

( [[ "/app/nginx" != $PREFIX_TENGINE ]] && test -d /app/nginx ) || ln -s $PREFIX_TENGINE /app/nginx
$PREFIX_TENGINE/sbin/nginx -v

cd $workdir/..

# copy logrotate
test -f nginx.service   && test -d /etc/systemd/system && cp nginx.service /etc/systemd/system 
test -f nginx.init      && test -d /etc/init.d/ && cp nginx.init /etc/init.d/nginx
test -f nginx.logrotate && \cp -f nginx.logrotate /etc/logrotate.d/nginx

# enable service
test -f /bin/systemctl && systemctl daemon-reload
which chkconfig && chkconfig nginx on
test -f /bin/systemctl && systemctl enable nginx
test -f /bin/systemctl || cp nginx.init /etc/init.d/nginx

# start service
#which service && service nginx start
#which service && service nginx status
