# Kerrigan-OpenResty

### 介绍
**Kerrigan**基于OpenResty开源项目进行的二次开发项目
主要功能：

- 动态负载均衡
- 动态黑白名单

### 软件架构

&emsp;&emsp;通过lua实现上述功能，并且配合openresty自身特性对代码某些部分进行优化。

#### [自定义组件函数库（openresty/lualib/resty/lepai）](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri )

&emsp;&emsp;这部分代码主要包含了写好的各种功能函数，在开发的时候尽量保持解耦和，通过2当中的lua脚本来引用。
- 基础组件函数库： **[basic](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/basic)** 
- IP黑白名单过滤组件函数库： **[black_white_ip](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/black_white_ip)** 
- 动态负载均衡组件函数库： **[upstream](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/upstream)** 
- 健康检查组件函数库：**[healthcheck](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/healthcheck)**
- Kerrigan初始化启动组件函数库： **[init_timers_lib](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/lualib/resty/kerri/init_timers_lib)** 



#### [运行时lua脚本组件（openresty/nginx/conf/lua）](https://github.com/HuaJuanJiang/kerrigan/tree/master/openresty/nginx/conf/lua)

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



### 组件说明











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
