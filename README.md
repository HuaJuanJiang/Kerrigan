# Kerrigan-OpenResty

![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/ranzhendong/kerrigan?include_prereleases&style=plastic)
![GitHub last commit (README.assets/master.svg)](https://img.shields.io/github/last-commit/ranzhendong/kerrigan/master?style=plastic)
![GitHub All Releases](https://img.shields.io/github/downloads/ranzhendong/kerrigan/total?style=plastic)
![GitHub](https://img.shields.io/github/license/ranzhendong/kerrigan?style=plastic)

- [Kerrigan-OpenResty](#Kerrigan-OpenResty)
  - [介绍](#介绍)
  - [软件架构](#软件架构)
    - [自定义函数库(openresty/lualib/resty/kerri)](#自定义函数库)
    - [运行时lua脚本(openresty/nginx/conf/lua)](#运行时lua脚本)
    - [shell&python脚本组件(openresty/nginx/script)](#shellpython脚本)

  - [安装](#安装)
    - [下载](#下载)
      - [说明](#说明)
    - [编译](#编译)
    - [检查](#检查)

  - [使用](#使用)
    - [sockproc配置](#sockproc配置)
    - [upstream配置](#upstream配置)
    - [nginx主配置](#nginx主配置)
      - [load lua file 变量](#load-lua-file变量)
      - [static html 变量](#static-html变量)
      - [logs dir 变量](#logs-dir变量)
      - [lua 配置](#lua配置)

    - [nginx子配置](#nginx子配置)
      - [args_lua_file](#args_lua_file)
      - [args_static_file](#args_static_file)
      - [args_logs_file](#args_logs_file)
      - [nginx upstream 配置](#nginx-upstream配置)
      - [black-white ip 黑白名单配置](#black-white-ip黑白名单配置)

    - [init初始化配置](#init初始化配置)
      - [woker number 工作进程配置](#woker-number工作进程配置)
      - [timer delay 定时器间隔配置](#timer-delay定时器间隔配置)
      - [timer file curl 定时器启动文件配置](#timer-file-curl定时器启动文件配置)
      - [upstream timer 初始化配置](#upstream-timer初始化配置)
      - [black ip timer 初始化配置](#black-ip-timer初始化配置)
      - [white ip timer 初始化配置](#white-ip-timer初始化配置)
      - [node name](#node-name)

    - [启动](#启动)
      - [语法检查](#语法检查)
      - [启动nginx](#启动nginx)
      - [查看日志](#查看日志)
      - [访问](#访问)

    - [常见错误](#常见错误)
      - [shell.sock failed](#shell-sock-failed)



</br></br></br>

## 介绍

</br>

**Kerrigan**基于OpenResty开源项目进行的二次开发项目
主要功能：

- 动态负载均衡
- 动态黑白名单



</br></br></br>

## 软件架构

&emsp;&emsp;通过lua实现上述功能，并且配合openresty自身特性对代码某些部分进行优化。



</br></br>

### [自定义函数库](https://github.com/ranzhendong/kerrigan/tree/master/openresty/lualib/resty/kerri )

&emsp;&emsp;这部分代码主要包含了写好的各种功能函数，在开发的时候尽量保持解耦和，通过2当中的lua脚本来引用。

&emsp;&emsp;**代码位置：openresty/lualib/resty/kerri**

- 基础组件函数库： **[basic](https://github.com/ranzhendong/kerrigan/tree/master/openresty/lualib/resty/kerri/basic)** 
- IP黑白名单过滤组件函数库： **[black_white_ip](https://github.com/ranzhendong/kerrigan/tree/master/openresty/lualib/resty/kerri/black_white_ip)** 
- 动态负载均衡组件函数库： **[upstream](https://github.com/ranzhendong/kerrigan/tree/master/openresty/lualib/resty/kerri/upstream)** 
- 健康检查组件函数库：**[healthcheck](https://github.com/ranzhendong/kerrigan/tree/master/openresty/lualib/resty/kerri/healthcheck)**
- Kerrigan初始化启动组件函数库： **[init_timers_lib](https://github.com/ranzhendong/kerrigan/tree/master/openresty/lualib/resty/kerri/init_timers_lib)** 



</br></br>

### [运行时lua脚本](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua)

&emsp;&emsp;这部分代码主要包含了通过暴露API接口来对Kerrigan项目内部的数据进行操作，包含增删改查，功能主体都是引用1当中写好的各种组件函数。

&emsp;&emsp;**代码位置：openresty/nginx/conf/lua**

- IP黑白名单过滤API接口：**[black_white_ip](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua/black_white_ip)**
- 控制动态负载均衡API接口：**[upstream](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua/upstream)**
- 查询DICT API接口： **[dict_select](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua/dict_select)**
- 数据同步定时器： **[init_timer](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua/init_timer)**
- 定时器拉起以及全局配置： **[init_timer_config](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua/init_timer_config)** 
- 其他功能脚本： **[script](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua/script)** 



</br></br>

### [shellpython脚本]( https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script )

&emsp;&emsp;这部分代码包含了定时器拉起组件将其他数据同步定时器拉起；初始化数据结构；以及lua执行外部shell脚本的能力。

&emsp;&emsp;**代码位置：openresty/nginx/script**

-  数据同步定时器拉起脚本：**[init_timer](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script/init_timer)**
- socket，lua执行shell命令脚本： **[socket](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script/socket)**
- 初始化upstream数据结构脚本： **[upstream](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script/upstream)**
- 消息发送脚本： **[send_message](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script/send_message)**



</br></br></br>

## 安装

</br>

### 下载

&emsp;&emsp;下载master分支代码。

&emsp;&emsp;解压安装到`/home/nginx`目录下。

&emsp;&emsp;需要说明的是：我的openresty版本是**1.15.8.2**，当前最新版本，编译参数在下面：

```shell
./configure --prefix=/home/nginx/openresty --with-luajit --with-http_ssl_module --user=nginx --group=nginx --with-http_realip_module --with-threads --with-http_auth_request_module --with-stream --with-stream_ssl_module  --with-stream_realip_module --with-pcre --with-http_stub_status_module
```

</br>



#### 说明

&emsp;&emsp;因为根据实际生产或者测试环境不一样，因为openresty实际运行位置是不固定的。因为我个人的习惯，以及习惯使用普通用户启动openresty，编译参数当中的`--prefix=/home/nginx/openresty`就是运行地址。

&emsp;&emsp;当使用**普通用户启动openresty**，默认是不允许运行和监听80端口，因此需要使用命令：`chown root nginx`和`chmod u+s nginx`。



</br></br>

### 编译

&emsp;&emsp;如果想安装openresty并启动在其他目录，需要自行去[官网](http://openresty.org/en/download.html)下载最新版本，进行编译安装，然后找到下面五个目录，注意这部分可选根据自身情况来选择执行：

[自定义函数库（openresty/lualib/resty/kerri）](https://github.com/ranzhendong/kerrigan/tree/master/openresty/lualib/resty/kerri )

解压复制到YouPath/lualib/resty/kerri



[运行时lua脚本（openresty/nginx/conf/lua）](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua)

解压复制到YouPath/nginx/conf/lua



[shell&python脚本组件（openresty/nginx/script）]( https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script )

解压复制到YouPath/nginx/script



[openresty主配置文件（openresty/nginx/conf/nginx.conf）](https://github.com/ranzhendong/kerrigan/blob/master/openresty/nginx/conf/nginx.conf)

解压复制到YouPath/nginx/conf



[openresty子配置文件（openresty/nginx/conf/conf.d）](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/conf.d)

解压复制到YouPath/nginx/conf/conf.d



&emsp;&emsp;最后保证目录结构和kerrigan一致就行。



</br></br>

### 检查

&emsp;&emsp;`./sbin/nginx -t`来进行检查，有下面输出就说明成功。

```shell
nginx: the configuration file /home/nginx/openresty/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /home/nginx/openresty/nginx/conf/nginx.conf test is successful
```



</br></br></br>

## 使用

&emsp;&emsp;使用前需要对openresty自身进行配置，以及kerrigan进行初始化设置。



</br></br>

### sockproc配置

&emsp;&emsp;在kerrigan项目当中，需要通过lua执行shell命令，因此开源项目**sockproc**就是完成这个事情的。

&emsp;&emsp;在**YouPath/nginx/script/socket**目录下，执行下面命令：`./sockproc shell.sock`即可，如果发现已有**shell.sock**文件，那么执行的时候就会报错，因此可以删除之后，再次执行，如果没有任何输出，说明执行成功。



</br></br>

### upstream配置

&emsp;&emsp;设置动态负载均衡初始upstream列表。

&emsp;&emsp;作用原理与普通nginx配置中的upstream相同，以upstream列表当中服务ip端口作为基准，进行转发以及健康检查，保证访问始终是不受影响的。

&emsp;&emsp;文件位置：[YouPath/nginx/script/upstream/init_upstream_conf/init_upstream_conf.json](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script/upstream/init_upstream_conf/init_upstream_conf.json)

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



</br></br>

### nginx主配置

&emsp;&emsp;因为需要写入文件路径过多，因此把主要路径都更改为变量，存放在nginx配置文件当中，主要集中在**http{}块儿**，map{}字段用来设置变量。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/nginx.conf](https://github.com/ranzhendong/kerrigan/blob/master/openresty/nginx/conf/nginx.conf)

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



</br>

#### load-lua-file变量

&emsp;&emsp;设置[运行时lua脚本](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/conf/lua)的位置，保证可以访问到下面的所有文件。

**&emsp;&emsp;$nginx_lua_home**为变量名，建议在变量后面把 **/** 加上，因为做路径拼接，必不可少。

```nginx
    map $args $nginx_lua_home {
        default "/home/nginx/openresty/nginx/conf/lua/";
        'seat'  1;
    }
```



</br>

#### static-html变量

&emsp;&emsp;**设置nginx访问静态页面根目录**，也就是html所在目录，之前使用绝对路径，因此避免不了下面`root /home/nginx/openresty/nginx/`的配置，但是需要配置项太多，因此在更改路径之后，需要更改的配置文件太多太分散，当然可以根据个人喜好，选择设置。

```nginx
    map $args $nginx_home {
        default "/home/nginx/openresty/nginx/";
        'seat'  1;
    }
```



</br>

#### logs-dir变量

&emsp;&emsp;**设置nginx日志根目录**，可以根据个人喜好设置，因为我个人习惯将日志打印在`/home/nginx/logs`下面，并且依据access log和error  log来进行区分，在后面配置文件也是这样体现。

&emsp;&emsp;**需要注意的是：**在主配置文件当中最上面规定的全局日志，需要写绝对路径或者启动的相对路径，不可以写成变量，因为nginx配置按行执行，变量在设置之前是无法读取的。

```nginx
    map $args $nginx_logs_home {
        default "/home/nginx/logs/";
        'seat'  1;
    }
```



</br>

#### lua配置

&emsp;&emsp;**openresty的lua部分基本配置**。包含lua_package_cpath这样的基本路径，这里我设置的启动路径的上一层，这里也可以写绝对路径。

- **init_worker_by_lua_file：**这个关键字一般用于在nignx启动的时候执行定时任务，这里**init_worker.lua**脚本的任务是拉起子定时器。
- **lua_shared_dict：**这里规定共享空间的大小，可以类比redis的存储空间。
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



</br></br>

### nginx子配置

&emsp;&emsp;这里主要集中在对于nginx内置变量的配置，包含**luafile**，**staticfile**和**logsfile**变量配置。



</br>

#### args_lua_file

&emsp;&emsp;包含`content_by_lua_file`字段需要加载的所有lua文件。

&emsp;&emsp;后面自己开发的lua脚本通过字段引用也可以写成变量到这个文件，保证后面子配置文件可以直接引用变量无需更改。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/conf.d/args_lua_file.conf]( https://github.com/ranzhendong/kerrigan/blob/master/openresty/nginx/conf/conf.d/args_lua_file.conf )

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



</br>

#### args_static_file

&emsp;&emsp;包含nginx子配置文件访问静态页面需要的文件夹变量。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/conf.d/args_static_html.conf]( https://github.com/ranzhendong/kerrigan/blob/master/openresty/nginx/conf/conf.d/args_static_html.conf )

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



</br>

#### args_logs_file

&emsp;&emsp;包含nginx子配置文件日志变量。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/conf.d/args_logs_file.conf]( https://github.com/ranzhendong/kerrigan/blob/master/openresty/nginx/conf/conf.d/args_logs_file.conf )

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



</br>

#### nginx-upstream配置

&emsp;&emsp;upstream配置和普通nginx配置相同，只不过需要`balancer_by_lua_block`块儿来调用[自定义函数库](https://github.com/ranzhendong/kerrigan/tree/master/openresty/lualib/resty/kerri )的connector_upstream模块，传入参数，通过模块读取dict共享内存当中的合适并且健康的upstream信息，通过`ngx.balancer.set_current_peer(ip, port)`关键字进行转发。

&emsp;&emsp;需要注意传入参数就是upstream列表名称，**需要保证它和所有upstream有关配置的唯一性以及一致性**。

&emsp;&emsp;文件位置：[YouPath/nginx/conf/conf.d/upstream.conf]( https://github.com/ranzhendong/kerrigan/blob/master/openresty/nginx/conf/conf.d/upstream.conf )

```nginx
# upstream 配置
upstream svmims {
    # server 0.0.0.0 必须保证存在，用于占位
    server 0.0.0.0;
    
    # balancer_by_lua_block代码块，引用包connector_upstream.lua，通过函数connector将参数传进去，
    # 必须保证参数的名字是和upstream配置当中的title以及外面名字相同
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



</br>

#### black-white-ip黑白名单配置

&emsp;&emsp;这部分是可选项，在第一次使用不建议使用，对项目熟悉后可以使用，主要是使用后不方便排错！

&emsp;&emsp;主要在需要进行访问控制的location前面增加代码块，通过access_by_lua关键字进行控制，需要在`cwi.connector('/api', 'b')`部分保证传入的第一个参数和location的相同，第二个参数来确定走黑名单还是白名单管理，

- w：表示受到白名单管理，只有在白名单的ip才可以访问特定的location，否则返回403。
- b：表示受到黑名单管理，只要有黑名单ip访问了特定的location就返回403.

```nginx
        access_by_lua_block {
            local cwi = require"resty.kerri.black_white_ip.connector_bw_ip"
            local cwi = cwi:new()
            local res = cwi.connector('/api', 'b')
        }
```

&emsp;&emsp;添加效果如下：

&emsp;&emsp;也可以参考[main_lua.conf(conf.d下面的子配置文件)](https://github.com/ranzhendong/kerrigan/blob/master/openresty/nginx/conf/conf.d/main_lua.conf)

```nginx
    location /api {
        access_by_lua_block {
            local cwi = require"resty.kerri.black_white_ip.connector_bw_ip"
            local cwi = cwi:new()
            local res = cwi.connector('/api', 'b')
        }
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Connection "";
        proxy_pass http://back;
    }
```



</br></br>

### init初始化配置

&emsp;&emsp;初始化的本质是通过openresty提供的**init_worker_by_lua**实现的，在初期，这部分被设计用来实现启动openresty后的定时任务例如心跳检查，定时拉取服务器配置的工作。

&emsp;&emsp;但是这里需要注意的是：如果有多个工作进行，则在启动的时候通过**init_worker_by_lua**启动两个相同的任务。



</br>

#### woker-number工作进程配置

&emsp;&emsp;在前面提到定时任务会启动多次，由于多个工作进程的关系，因此通过**ngx.worker.id**变量来对具体执行定时任务的woker 进程进行分配，保证启动的时候每个定时任务只启动一次。

```lua
-------------------------------- 定时器执行的 nginx 工作进程配置 ----------------------------------------
local ip_worker_num                   = 0 -- 选择第1个worker执行ip timer定时任务 

local upstream_worker_num             = 2 -- 选择第3个worker执行upstream timer定时任务

local healthcheck_worker_num          = 2 -- 选择第3个worker执行healthcheck timer定时任务

local init_upstream_config_num        = 0 -- 选择第1个worker执行init upstream config定时任务

local bip_gain_worker_num             = 1 -- 选择第2个worker执行black ip gain定时任务

local state_sync_worker_num           = 0 -- 选择第1个worker执行state sync定时任务

local node_heartbeat_worker_num       = 1 -- 选择第2个worker执行node heartbeat定时任务

local upserver_sync_worker_num        = 1 -- 选择第2个worker执行upserver sync定时任务
```



</br>

#### timer-delay定时器间隔配置

&emsp;&emsp;用来控制定时器的执行间隔，也就是多少秒执行一次。

```lua
------------------------------------- 定时器事件间隔配置 ------------------------------------------------
-- 建议除了“node heartbeat”和“upserver sync”之外所有定时器的其他定时器的时间间隔大于等于2秒
local main_timer_delay                = 0  -- 主定时器执行间隔，nginx启动后执行其他定时器的间隔，建议为0，立即启动

local wbip_delay                      = 5  -- white ip 定时器执行间隔

local init_upstream_config_delay      = 2  -- init upstream config初始化upstream配置定时器执行间隔

local upstream_delay                  = 10 -- upstream动态拉取配置定时器执行间隔

local healthcheck_delay               = 8  -- healthcheck健康检查定时器执行间隔

local bip_gain_delay                  = 5  -- black ip gain定时器执行间隔

local state_sync_delay                = 5  -- state sync定时器执行间隔

local node_heartbeat_delay            = 1  -- node heartbeat 定时器执行间隔

local upserver_sync_delay             = 1  -- upserver 状态同步定时器执行间隔
```



</br>

#### timer-file-curl定时器启动文件配置

&emsp;&emsp;在init_worker_by_lua当中，**不可以执行阻塞命令**，但是定时器当中有很多代码都不符合这样的规则，因此选择通过一个取巧的办法，将定时器挂到一个server的location下面，访问特定域名的location实现激活定时器，访问的过程则选择了外部执行shell命令通过curl来实现，每个定时器的curl命令的url不一样，因此不同的定时器对应不同文件。

&emsp;&emsp;后面可以通过内置http库通过内部访问，这样的访问方式就丢弃了。

&emsp;&emsp;shell脚本位置：[YouPath/nginx/script/init_timer](  https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script/init_timer )

```lua
-------------------------------------- 定时器文件名配置 ------------------------------------------------
local wbip_timer_file                 = 'wbip_timer.sh'

local init_upstream_config_timer_file = 'init_upstream_config_timer.sh'

local dynamic_upstream_timer_file     = 'dynamic_upstream_timer.sh'

local healthcheck_timer_file          = 'healthcheck_timer.sh'

local bip_gain_timer_file             = 'bip_gain_timer.sh'

local state_sync_timer_file           = 'state_sync_timer.sh'

local node_heartbeat_timer_file       = 'node_heartbeat_timer.sh'

local upserver_sync_timer_file        = 'upserver_sync_timer.sh'
```



</br>

#### upstream-timer初始化配置

&emsp;&emsp;upstream 初始化定时器配置，主要是定义要读取的upstream json文件位置，从中读取upstream信息。

&emsp;&emsp;默认的位置是：[YouPath/nginx/script/upstream/init_upstream_conf/init_upstream_conf.json](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx/script/upstream/init_upstream_conf/init_upstream_conf.json)，但是可以根据自身部署的位置进行更换，也就是需要将变量**init_upstream_config_filepath**进行替换，其他的如文件名也可以根据自身需求进行更换。

```lua
------------------------------ init upstream conf 定时器配置文件 ---------------------------------------
local init_upstream_config_state = 'uncover'
-- init upstream conf script path

local init_upstream_config_filepath = '/home/nginx/openresty/nginx/script/upstream/init_upstream_conf'

-- init upstream json conf
local init_upstream_config_jsonfile = 'init_upstream_conf.json'

-- init upstream python script
local init_upstream_config_pythonfile = 'json_format.py'

--python_cmd
local python_cmd = '/usr/bin/python '
```



</br>

#### black-ip-timer初始化配置

&emsp;&emsp;black ip 定时器初始化配置，包含了日志的位置，以及设置ip黑名单过期时间，也就是在多少个小时之后黑名单ip将过期。

```lua
--------------------------------- black ip gain 定时器配置文件 ----------------------------------------
-- 日志位置
local bip_gain_timer_logfile = '/home/nginx/logs/accesslog/black-ip-access.log'

-- 设置过期时间（单位: 小时）
local bip_gain_timer_exptime = 8

-- black ip 出现次数大于多少次，就进行记录，否则视为误访问，并不记录
local bip_gain_timer_count = 1
```



</br>

#### white-ip-timer初始化配置

```lua
-- 在定时器启动之前先对白名单进行设置，因为定时器所在的location是受到白名单保护的，
-- 因此对于通过shell进行curl触发访问的操作是需要127.0.0.1的ip是在白名单内的。
wip_zone:set('127.0.0.1', 'reset')

-- 白名单列表，只有下列ip才是可以进行对受保护的特定location进行访问
local init_white_ip_tab =
{
    "127.0.0.1",
    "192.168.1.122"
}
```



</br>

#### node-name

&emsp;&emsp;在多节点的情况下，需要对每个节点进行命名



</br></br>

### 启动

&emsp;&emsp;在按照上面的进行配置以后尝试启动。



</br>

#### 语法检查

&emsp;&emsp;首先进行语法检查，保证变量设置以及基本server upstream是正确的。

&emsp;&emsp;必须在[YouPath/nginx](https://github.com/ranzhendong/kerrigan/tree/master/openresty/nginx)目录下启动，需要为相对路径，对于非root用户监听80和443端口，需要`chown root ./sbin/nginx`和`chmod u+s ./sbin/nginx`才可以正常访问。

```shell
[nginx@nginx nginx]$ ./sbin/nginx -t
nginx: the configuration file /home/nginx/openresty/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /home/nginx/openresty/nginx/conf/nginx.conf test is successful
```



</br>

#### 启动nginx

```shell
[nginx@nginx nginx]$ ./sbin/nginx -s
```



</br>

#### 查看日志

&emsp;&emsp;在openresty开发当中，所有通过lua输出的日志无论是什么类型，都是默认打印在nginx配置文件当中定义error_log的地方，并且需要指定日志级别为info。

&emsp;&emsp;在nginx.conf主配置文件，可以看到在开头的配置，这个就是默认把所有server访问以及名下的lua打印的日志都输出到`logs/error.log`位置，相对于启动路径。

&emsp;&emsp;如果有需求需要不同的server的lua输出日志打印在server下，则需要在server定义error_log，并且指定日志输出级别为info。

```nginx
error_log logs/error.log;
error_log logs/error.log info;
```

在`tailf logs/error.log`命令下，一直在刷日志，说明基本上是启动成功了。



</br>

#### 访问

&emsp;&emsp;通过浏览器进行访问，并且看输出日志



</br></br>

### 常见错误

&emsp;&emsp;在启动nginx的时候会遇到很多错误，是通过`./sbin/nginx -t`无法检查出来的，看项目是否真的启动成功，需要查看错误日志error.log。



</br>

#### shell-sock-failed

&emsp;&emsp;当日志报错如下，尤其是`connect() to unix:/home/nginx/openresty/nginx/script/socket/shell.sock failed (111: Connection refused)`说明没有在启动nginx之前将sockproc脚本启动，在没有对kerrigan进行更新之前，都是采用shell命令的形式触发定时器，因此可以根据上面的[sockproc配置](#sockproc配置)来解决问题。

```bash
2019/11/25 14:31:40 [error] 13008#13008: *5 connect() to unix:/home/nginx/openresty/nginx/script/socket/shell.sock failed (111: Connection refused), context: ngx.timer
2019/11/25 14:31:40 [error] 13008#13008: *5 [lua] init_worker_timers.lua:32: [ ERR ]: BLACK WHITE IP TIMER script execute failed ! ! !, context: ngx.timer
```



</br></br>

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
