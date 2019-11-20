# Kerrigan-OpenResty

### 介绍
**Kerrigan**基于OpenResty开源项目进行的二次开发项目
主要功能：

- 动态负载均衡
- 动态黑白名单

### 软件架构

&emsp;&emsp;通过lua实现上述功能，并且配合openresty自身特性对代码某些部分进行优化。

#### [自定义函数库（openresty/lualib/resty/kerri）](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri )

&emsp;&emsp;这部分代码主要包含了写好的各种功能函数，在开发的时候尽量保持解耦和，通过2当中的lua脚本来引用。
- 基础组件函数库： **[basic](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/basic)** 
- IP黑白名单过滤组件函数库： **[black_white_ip](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/black_white_ip)** 
- 动态负载均衡组件函数库： **[upstream](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/upstream)** 
- 健康检查组件函数库：**[healthcheck](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/healthcheck)**
- Kerrigan初始化启动组件函数库： **[init_timers_lib](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/init_timers_lib)** 



#### [运行时lua脚本（openresty/nginx/conf/lua）](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua)

&emsp;&emsp;这部分代码主要包含了通过暴露API接口来对Kerrigan项目内部的数据进行操作，包含增删改查，功能主体都是引用1当中写好的各种组件函数。

- IP黑白名单过滤API接口：**[black_white_ip](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/black_white_ip)**
- 控制动态负载均衡API接口：**[upstream](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/upstream)**
- 查询DICT API接口： **[dict_select](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/dict_select)**
- 数据同步定时器： **[init_timer](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/init_timer)**
- 定时器拉起以及全局配置： **[init_timer_config](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/init_timer_config)** 
- 其他功能脚本： **[script](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua/script)** 



#### [shell&python脚本组件（openresty/nginx/script）]( https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script )

&emsp;&emsp;这部分代码包含了定时器拉起组件将其他数据同步定时器拉起；初始化数据结构；以及lua执行外部shell脚本的能力。

-  数据同步定时器拉起脚本：**[init_timer](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/init_timer)**
- socket，lua执行shell命令脚本： **[socket](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/socket)**
- 初始化upstream数据结构脚本： **[upstream](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/upstream)**
- 消息发送脚本： **[send_message](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/script/send_message)**



### 安装

#### 下载

&emsp;&emsp;下载master分支代码。

&emsp;&emsp;解压安装到`/home/nginx`目录下。

&emsp;&emsp;需要说明的是：我的openresty版本是**1.15.8.2**，当前最新版本，编译参数在下面：

```shell
./configure --prefix=/home/nginx/openresty --with-luajit --with-http_ssl_module --user=nginx --group=nginx --with-http_realip_module --with-threads --with-http_auth_request_module --with-stream --with-stream_ssl_module  --with-stream_realip_module --with-pcre --with-http_stub_status_module
```

##### 说明

&emsp;&emsp;因为根据实际生产或者测试环境不一样，因为openresty实际运行位置是不固定的。因为我个人的习惯，以及习惯使用普通用户启动openresty，编译参数当中的`--prefix=/home/nginx/openresty`就是运行地址。

&emsp;&emsp;当使用**普通用户启动openresty**，默认是不允许运行和监听80端口，因此需要使用命令：`chown root nginx`和`chmod u+s nginx`。



#### 编译（可选）

&emsp;&emsp;如果想安装openresty并启动在其他目录，需要自行去[官网](http://openresty.org/en/download.html)下载最新版本，进行编译安装，然后找到下面五个目录：

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



#### 检查

&emsp;&emsp;`./sbin/nginx -t`来进行检查，有下面输出就说明成功。

```shell
nginx: the configuration file /home/nginx/openresty/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /home/nginx/openresty/nginx/conf/nginx.conf test is successful
```



### 使用

&emsp;&emsp;使用前需要对openresty自身进行配置，以及kerrigan进行初始化设置。

#### 启动sockproc

&emsp;&emsp;在kerrigan项目当中，需要通过lua执行shell命令，因此开源项目**sockproc**就是完成这个事情的。

&emsp;&emsp;在**YouPath/nginx/script/socket**目录下，执行下面命令：`./sockproc shell.sock`即可，如果发现已有**shell.sock**文件，那么执行的时候就会报错，因此可以删除之后，再次执行，如果没有任何输出，说明执行成功。



#### 设置upstream

&emsp;&emsp;设置动态负载均衡初始upstream列表，在**YouPath/nginx/script/upstream/init_upstream_conf**目录下，**init_upstream_conf.json**文件中进行修改。

&emsp;&emsp;作用原理与普通nginx配置中的upstream相同，以upstream列表当中服务ip端口作为基准，进行转发以及健康检查，保证访问始终是不受影响的。

&emsp;&emsp;因此在nginx配置文件的upstream块儿当中指定后端服务器IP地址以及端口，但是在kerrigan项目当中，则是以json形式展现，下面是一个示例：

```json
{    
    //upstream名称，根据自身业务命名
    "ew_20": {
        // 算法选择，目前只支持轮询（roundrobin）
        // 以及加权轮询
        "algo": "ip_hex",
        
        // 连接池
        "pool": {
            
            // server名称，对应的是nginx upstream当中
            // 一条转发规则
            "server1": {
                
                // ip和端口
                "ip_port": "127.0.0.1:8888",
                
                // 标志位，形容目前server1的状态，
                // 包含下面三种情况
                // up   当前server处于活跃状态，
                //      可以对外提供服务，健康检查成功
                // down 当前server处于问题状态，
                //      不可以提供服务，健康检查失败
                // nohc 当前server处于未知状态，
                //      不做健康检查！
                "status": "up",
                
                // 权重，如果带加权，则可以和其他已有
                // server设置的不一致，如果设置数字一样，
                // 就是普通轮询
                "weight": "2"
            },
            // server名称需要和前面不一样，
            // 并且建议按照顺序
            "server2": {
                "ip_port": "127.0.0.1:9999",
                "status": "up",
                "weight": "1"
            }
        },
        // 数据结构名称
        "title": "ew_20"
    }
}
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
