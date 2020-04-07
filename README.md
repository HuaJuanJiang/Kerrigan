# Kerrigan-OpenResty Eleven

![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/ranzhendong/kerrigan?include_prereleases&style=plastic&color=00CC33)
![GitHub repo size](https://img.shields.io/github/repo-size/ranzhendong/kerrigan?style=plastic&color=important)
![GitHub last commit (branch)](https://img.shields.io/github/last-commit/ranzhendong/kerrigan/eleven?style=plastic&color=99CC00)
![GitHub](https://img.shields.io/github/license/ranzhendong/kerrigan?style=plastic&color=blueviolet)



</br></br>

## 介绍

</br>

**Kerrigan**基于OpenResty开源项目进行的二次开发项目
主要功能：

- 动态负载均衡
- 动态黑白名单



</br></br></br>

## 软件架构

&emsp;&emsp;使用golang对大部分之前用lua实现的代码进行重构。加入Etcd作为存储介质，并借助watcher机制来实现多节点数据协同。

​		架构图（可能会更改）

![Kerrigan Architecture Map](.image/KerriganArchitectureMap.png)

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
