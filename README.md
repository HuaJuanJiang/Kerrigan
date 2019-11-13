# Kerrigan-Openresty

#### 介绍
Kerrigan开源项目
依靠Openresty开源项目进行的二次开发项目
主要功能：动态负载均衡、动态黑白名单

#### 软件架构
​		由于项目是依据openresty项目开发的，因此代码大部分都保存在了两个部分，方便大家查看


1. lualib 

目录：openresty/openresty-1.15.8.1/lualib/resty/lepai
   		这部分代码主要包含了写好的各种功能函数，在开发的时候尽量保持解耦和，通过2当中的lua脚本来引用。
包含：
   
    - 基础函数模块：basic
    - IP黑白名单过滤模块：black_white_ip
    - 动态负载均衡模块：upstream
    - 健康检查模块：healthcheck
    - Kerrigan初始化启动模块：init_timers_lib
   
2. conf/lua
    
目录：openresty/openresty-1.15.8.1/nginx/conf/lua
		这部分代码主要包含了通过暴露API接口来对Kerrigan项目内部的数据进行操作，包含增删改查，功能主体都是引用1当中写好的
    各种函数；定时器在这里也占有很大比重。
    包含：
    
    - IP黑白名单过滤API接口：black_white_ip
    - 控制动态负载均衡API接口：upstream
    - 查询DICT API接口：dict_select
    - 定时器：init_timer
    - 定时器以及全局配置：init_timer_config
    - 其他脚本：script
    

#### 安装教程

1. xxxx
2. xxxx
3. xxxx

#### 使用说明

1. xxxx
2. xxxx
3. xxxx

#### 参与贡献

1. Fork 本仓库
2. 新建 Feat_xxx 分支
3. 提交代码
4. 新建 Pull Request

Copyright & License

BSD 2-Clause License

Copyright (c) 2019, Zhendong
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
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
