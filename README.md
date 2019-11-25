# Kerrigan-OpenResty

- [Kerrigan-OpenResty](#Kerrigan-OpenResty)
  - [介绍](#介绍)
  - [软件架构](#软件架构)
    - [自定义函数库(openresty/lualib/resty/kerri)](#自定义函数库)
    - [运行时lua脚本(openresty/nginx/conf/lua)](#运行时lua脚本)
    - [shell&python脚本组件(openresty/nginx/script)](#shell&python脚本组件)
  - [安装](#安装)
    - [下载](#下载)
      - [说明](#说明)
    - [编译](#编译)
    - [检查](#检查)
  - [使用](#使用)
    - [启动sockproc](#启动sockproc)
    - [设置upstream](#设置upstream)
- [Copyright & License](#Copyright & License)

## 介绍
**Kerrigan**基于OpenResty开源项目进行的二次开发项目
主要功能：

- 动态负载均衡
- 动态黑白名单

## 软件架构

&emsp;&emsp;通过lua实现上述功能，并且配合openresty自身特性对代码某些部分进行优化。

### [自定义函数库](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri )

&emsp;&emsp;这部分代码主要包含了写好的各种功能函数，在开发的时候尽量保持解耦和，通过2当中的lua脚本来引用。

&emsp;&emsp;**代码位置：openresty/lualib/resty/kerri**

- 基础组件函数库： **[basic](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/basic)** 
- IP黑白名单过滤组件函数库： **[black_white_ip](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/black_white_ip)** 
- 动态负载均衡组件函数库： **[upstream](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/upstream)** 
- 健康检查组件函数库：**[healthcheck](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/healthcheck)**
- Kerrigan初始化启动组件函数库： **[init_timers_lib](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/init_timers_lib)** 



### [运行时lua脚本](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua)

&emsp;&emsp;这部分代码主要包含了通过暴露API接口来对Kerrigan项目内部的数据进行操作，包含增删改查，功能主体都是引用1当中写好的各种组件函数。

&emsp;&emsp;**代码位置：openresty/nginx/conf/lua**

- IP黑白名单过滤API接口：**[black_white_ip](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/black_white_ip)**
- 控制动态负载均衡API接口：**[upstream](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/upstream)**
- 查询DICT API接口： **[dict_select](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/dict_select)**
- 数据同步定时器： **[init_timer](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/init_timer)**
- 定时器拉起以及全局配置： **[init_timer_config](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/init_timer_config)** 
- 其他功能脚本： **[script](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/script)** 



### [shell&python脚本组件]( https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script )

&emsp;&emsp;这部分代码包含了定时器拉起组件将其他数据同步定时器拉起；初始化数据结构；以及lua执行外部shell脚本的能力。

&emsp;&emsp;**代码位置：openresty/nginx/script**

-  数据同步定时器拉起脚本：**[init_timer](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/init_timer)**
- socket，lua执行shell命令脚本： **[socket](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/socket)**
- 初始化upstream数据结构脚本： **[upstream](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/upstream)**
- 消息发送脚本： **[send_message](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/send_message)**



## 安装

### 下载

&emsp;&emsp;下载master分支代码。

&emsp;&emsp;解压安装到`/home/nginx`目录下。

&emsp;&emsp;需要说明的是：我的openresty版本是**1.15.8.2**，当前最新版本，编译参数在下面：

```shell
./configure --prefix=/home/nginx/openresty --with-luajit --with-http_ssl_module --user=nginx --group=nginx --with-http_realip_module --with-threads --with-http_auth_request_module --with-stream --with-stream_ssl_module  --with-stream_realip_module --with-pcre --with-http_stub_status_module
```

#### 说明

&emsp;&emsp;因为根据实际生产或者测试环境不一样，因为openresty实际运行位置是不固定的。因为我个人的习惯，以及习惯使用普通用户启动openresty，编译参数当中的`--prefix=/home/nginx/openresty`就是运行地址。

&emsp;&emsp;当使用**普通用户启动openresty**，默认是不允许运行和监听80端口，因此需要使用命令：`chown root nginx`和`chmod u+s nginx`。



### 编译

&emsp;&emsp;如果想安装openresty并启动在其他目录，需要自行去[官网](http://openresty.org/en/download.html)下载最新版本，进行编译安装，然后找到下面五个目录，注意这部分可选根据自身情况来选择执行：

[自定义函数库（openresty/lualib/resty/kerri）](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri )

解压复制到YouPath/lualib/resty/kerri



[运行时lua脚本（openresty/nginx/conf/lua）](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua)

解压复制到YouPath/nginx/conf/lua



[shell&python脚本组件（openresty/nginx/script）]( https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script )

解压复制到YouPath/nginx/script



[openresty主配置文件（openresty/nginx/conf/nginx.conf）](https://github.com/HuaJuanJiang/kerrigan/blob/master/openresty/nginx/conf/nginx.conf)

解压复制到YouPath/nginx/conf



[openresty子配置文件（openresty/nginx/conf/conf.d）](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/conf.d)

解压复制到YouPath/nginx/conf/conf.d



&emsp;&emsp;最后保证目录结构和kerrigan一致就行。



### 检查

&emsp;&emsp;`./sbin/nginx -t`来进行检查，有下面输出就说明成功。

```shell
nginx: the configuration file /home/nginx/openresty/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /home/nginx/openresty/nginx/conf/nginx.conf test is successful
```



## 使用

&emsp;&emsp;使用前需要对openresty自身进行配置，以及kerrigan进行初始化设置。

### sockproc配置

&emsp;&emsp;在kerrigan项目当中，需要通过lua执行shell命令，因此开源项目**sockproc**就是完成这个事情的。

&emsp;&emsp;在**YouPath/nginx/script/socket**目录下，执行下面命令：`./sockproc shell.sock`即可，如果发现已有**shell.sock**文件，那么执行的时候就会报错，因此可以删除之后，再次执行，如果没有任何输出，说明执行成功。



### upstream配置

&emsp;&emsp;设置动态负载均衡初始upstream列表，在**[YouPath/nginx/script/upstream/init_upstream_conf](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/upstream/init_upstream_conf)**目录下，**init_upstream_conf.json**文件中进行修改。

&emsp;&emsp;作用原理与普通nginx配置中的upstream相同，以upstream列表当中服务ip端口作为基准，进行转发以及健康检查，保证访问始终是不受影响的。

&emsp;&emsp;因此在nginx配置文件的upstream块儿当中指定后端服务器IP地址以及端口，但是在kerrigan项目当中，则是以json形式展现，下面是一个示例：

```json
{    

    "//": "upstream名称，根据自身业务命名",
    "ew_20": {

        "//": "算法选择，目前只支持轮询（roundrobin）;以及加权轮询（weight roundrobin）,其他算法目前没有支持",
        "algo": "ip_hex",
        
        "//": "连接池",
        "pool": {
            
            "//": "server名称，对应的是nginx upstream当中一条转发规则",
            "server1": {
                
                "//": "ip和端口",
                "ip_port": "127.0.0.1:8888",
                
                "//": "标志位，形容目前server1的状态，包含下面三种情况",
                "//": "up   当前server处于活跃状态，可以对外提供服务，健康检查成功",
                "//": "down 当前server处于问题状态，不可以提供服务，健康检查失败",
                "//": "nohc 当前server处于未知状态，不做健康检查！",
                "status": "up",
                
                "//": "权重，如果带加权，则可以和其他已有server设置的不一致，如果设置数字一样，就是普通轮询",
                "weight": "2"
            },

            "//": "server名称需要和前面不一样，并且建议按照顺序",
            "server2": {
                "ip_port": "127.0.0.1:9999",
                "status": "up",
                "weight": "1"
            }
        },
        "//": "数据结构名称",
        "title": "ew_20"
    }
}
```



### nginx.conf配置

&emsp;&emsp;因为需要写入文件路径过多，因此把主要路径都更改为变量，存放在nginx配置文件当中，主要集中在**http{}块儿**，map{}字段用来设置变量。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/nginx.conf](https://github.com/HuaJuanJiang/kerrigan/blob/master/openresty/nginx/conf/nginx.conf)

```nginx
http {
    # lua
    # nginx_lua_home for load lua file
    map $args $nginx_lua_home {
        default "/home/nginx/openresty/nginx/conf/lua/";
        'seat'  1;
    }
    # nginx_home for static html
    map $args $nginx_home {
        default "/home/nginx/openresty/nginx/";
        'seat'  1;
    }
    # nginx_logs_home for logs dir
    map $args $nginx_logs_home {
        default "/home/nginx/logs/";
        'seat'  1;
    }
}
```



#### load lua file 

&emsp;&emsp;设置[运行时lua脚本](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua)的位置，保证可以访问到下面的所有文件。

**&emsp;&emsp;$nginx_lua_home**为变量名，建议在变量后面把 **/** 加上，因为做路径拼接，必不可少。

```nginx
    map $args $nginx_lua_home {
        default "/home/nginx/openresty/nginx/conf/lua/";
        'seat'  1;
    }
```



#### static html

&emsp;&emsp;**设置nginx访问静态页面根目录**，也就是html所在目录，之前使用绝对路径，因此避免不了下面`root /home/nginx/openresty/nginx/`的配置，但是需要配置项太多，因此在更改路径之后，需要更改的配置文件太多太分散，当然可以根据个人喜好，选择设置。

```nginx
    map $args $nginx_home {
        default "/home/nginx/openresty/nginx/";
        'seat'  1;
    }
```



#### logs dir

&emsp;&emsp;**设置nginx日志根目录**，可以根据个人喜好设置，因为我个人习惯将日志打印在`/home/nginx/logs`下面，并且依据access log和error  log来进行区分，在后面配置文件也是这样体现。

&emsp;&emsp;**需要注意的是：**在主配置文件当中最上面规定的全局日志，需要写绝对路径或者启动的相对路径，不可以写成变量，因为nginx配置按行执行，变量在设置之前是无法读取的。

```nginx
    map $args $nginx_logs_home {
        default "/home/nginx/logs/";
        'seat'  1;
    }
```



#### lua 配置

&emsp;&emsp;**openresty的lua部分基本配置**。包含lua_package_cpath这样的基本路径，这里我设置的启动路径的上一层，这里也可以写绝对路径。

- **init_worker_by_lua_file：**这个关键字一般用于在nignx启动的时候执行定时任务，这里**init_worker.lua**脚本的任务是拉起子定时器。
- **lua_shared_dict：**这里规定共享空间的大小，可以类比redis的存储空间
- 其他的参数以及含义可以参考openresty官网的配置。

```nginx
    # 必须以相对路径启动
    init_worker_by_lua_file "conf/lua/init_timer_config/init_worker.lua";
    lua_package_cpath "../lualib/?.so;;";
    lua_package_path "../lualib/resty/?.lua;;";
    lua_shared_dict cookie_collector_zone 1m;
    lua_shared_dict white_ip_zone         5m;
    lua_shared_dict black_ip_zone         200m;
    lua_shared_dict auth_zone             50m;
    lua_shared_dict upstream_zone         50m;
    lua_shared_dict healthcheck_zone      50m;
    #lua_code_cache off;
    lua_code_cache on;
    lua_check_client_abort on;
    lua_max_running_timers 512;
    lua_max_pending_timers 1024;
```



### nginx子配置

&emsp;&emsp;这里主要集中在对于nginx内置变量的配置，包含**luafile**，**staticfile**和**logsfile**变量配置。

#### lua_file

&emsp;&emsp;包含`content_by_lua_file`字段需要加载的所有lua文件。

&emsp;&emsp;后面自己开发的lua脚本通过字段引用也可以写成变量到这个文件，保证后面子配置文件可以直接引用变量无需更改。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/conf.d/args_lua_file.conf]( https://github.com/HuaJuanJiang/kerrigan/blob/master/openresty/nginx/conf/conf.d/args_lua_file.conf )

```nginx
# 所有需要加载的lua文件路径配置

# dict_select
map $args $dict_select {
        default "dict_select/dict_select.lua";
            'seat'  1;
}

# wbip_timer
map $args $wbip_timer {
        default "init_timer/black_white_ip_timer.lua";
            'seat'  1;
}

# auth_timer 
map $args $auth_timer {
        default "init_timer/auth_timer.lua";
            'seat'  1;
}
....
```



#### static_file

&emsp;&emsp;包含nginx子配置文件访问静态页面需要的文件夹变量。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/conf.d/args_static_html.conf]( https://github.com/HuaJuanJiang/kerrigan/blob/master/openresty/nginx/conf/conf.d/args_static_html.conf )

```nginx
# 前端代码root访问变量
# vmims
map $args $vmims_static {
        default "vmims_html";
        'seat'  1;
}

# ew
map $args $ew_static {
        default "ew_static_html";
        'seat'  1;
}
.....
```



#### logs_file

&emsp;&emsp;包含nginx子配置文件日志变量。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/conf.d/args_logs_file.conf]( https://github.com/HuaJuanJiang/kerrigan/blob/master/openresty/nginx/conf/conf.d/args_logs_file.conf )

```nginx
# 日志文件变量
# vmims
map $args $vmims_log {
        default "vmims.log";
        'seat'  1;
}

# ew
map $args $ew_log {
        default "ew.log";
        'seat'  1;
}

# 7hetech
map $args $7hetech_log {
        default "7hetech.log";
        'seat'  1;
}
```



#### nginx upstream配置

&emsp;&emsp;upstream配置和普通nginx配置相同，只不过需要`balancer_by_lua_block`块儿来调用[自定义函数库](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri )的connector_upstream模块，传入参数，通过模块读取dict共享内存当中的合适并且健康的upstream信息，通过`ngx.balancer.set_current_peer(ip, port)`关键字进行转发。

&emsp;&emsp;需要注意传入参数就是upstream列表名称，**需要保证它和所有upstream有关配置的唯一性以及一致性**。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/conf.d/upstream.conf]( https://github.com/HuaJuanJiang/kerrigan/blob/master/openresty/nginx/conf/conf.d/upstream.conf )

```nginx
# upstream 配置
upstream svmims {
    # server 0.0.0.0 必须保证存在，用于占位
    server 0.0.0.0;
    
    # balancer_by_lua_block代码块，引用包connector_upstream.lua，通过函数connector将参数传进去，必须保证参数的名字是和upstream配置当中的title以及外面名字相同
    balancer_by_lua_block {
        local cu = require"resty.kerri.upstream.connector_upstream"
        local clp = cu:new()
        clp.connector('svmims')
    }
}

upstream vmims {
    server 0.0.0.0;
    balancer_by_lua_block {
        local cu = require"resty.kerri.upstream.connector_upstream"
        local clp = cu:new()
        clp.connector('vmims')
    }
}

upstream ew_10 {
        server 0.0.0.0;
        balancer_by_lua_block {
                local cu = require"resty.kerri.upstream.connector_upstream"
                local clp = cu:new()
                clp.connector('ew_10')
        }
}
....
```















# Copyright & License

BSD 2-Clause License

Copyright (c) 2019, Zhendong
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.