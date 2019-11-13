#!/usr/bin/env python2
#coding:utf-8 
import requests,sys,json,os
import urllib3
from requests.packages.urllib3.exceptions import InsecureRequestWarning
urllib3.disable_warnings()
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

Url = "https://oapi.dingtalk.com/robot/send?access_token=6f3546f134b96495a378382ca427fb6f985dd8b631fbfa3e4a65c6ec77411dd1" 

def SendMessage(Subject,Content):
    Header = {
	"Content-Type": "application/json", 
	"Charset": "UTF-8" 
    }

    Data = {
	"msgtype": "text", 
	"text": { 
		"content": Subject + '\n' + Content, 
	},
    }
    r = requests.post(url=Url,data=json.dumps(Data),headers=Header,verify=False)
    return r.text

if __name__ == '__main__':
      #Subject='                    IP白名单消息提醒'
      Subject=str(sys.argv[1])
      Content=str(sys.argv[2])
      Status = SendMessage(Subject,Content)
      print Status
