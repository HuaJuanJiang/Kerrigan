#!/usr/bin/env python2
# -*- coding: utf-8 -*-
import requests,sys,json,os
import urllib3
from requests.packages.urllib3.exceptions import InsecureRequestWarning
urllib3.disable_warnings()

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
User = "RanZhenDong"                                    # 这里添用户，给哪个用户添
Corpid = "wwfd36d4b4c27822e1"                           # CorpID是企业号的标识
Secret = "kwBSU74_qShZ7NMfyEeE6EMK7lUBgZ2pcyRrEYC4yUc"  # Secret是管理组凭证密钥
Tagid = "Raspberry"                                     # 通讯录标签ID,也就是部门ID，
Agentid = "1000005"                                     # 应用ID

def GetToken(Corpid,Secret):
    Url = "https://qyapi.weixin.qq.com/cgi-bin/gettoken"
    Data = {
        "corpid":Corpid,
        "corpsecret":Secret,
    }
    r = requests.get(url=Url,params=Data,verify=False)
    Token = r.json()['access_token']
    return Token

def SendMessage(Token,User,Agentid,Subject,Content):
    Url = "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=%s" % Token
    Data = {
        "touser": User,                                 # 企业号中的用户帐号，在zabbix用户Media中配置，如果配置不正常，将按部门发送。
        "totag": Tagid,                                 # 企业号中的部门id，群发时使用。
        "msgtype": "text",                              # 消息类型。
        "agentid": Agentid,                             # 企业号中的应用id。
        "text": {
            "content": Subject + '\n' + Content,
        },
        "safe": "0",
    }
    r = requests.post(url=Url,data=json.dumps(Data),verify=False)
    return r.text
if __name__ == '__main__':
      Token = GetToken(Corpid, Secret)
      #Subject='                    IP白名单消息提醒'
      Subject=str(sys.argv[1])
      Content=str(sys.argv[2])
      Status = SendMessage(Token,User,Agentid,Subject,Content)
      # print Status
        





