#!/usr/bin/python
#coding:utf-8   #强制使用utf-8编码格式
import smtplib,sys  #加载smtplib模块
from email.mime.text import MIMEText
from email.utils import formataddr
my_sender='ranzhendong@egaga.cn' #发件人邮箱账号，为了后面易于维护，所以写成了变量
#send_to='zhendongran@dingtalk.com' #收件人邮箱账号，为了后面易于维护，所以写成了变量
my_passwd='qaz19940922Rzd'
smtp_addr='smtp.exmail.qq.com'
smtp_port='25'
Whoisme='DongDong'

def send_mail(Whoisme, Subject, Content, Send_To):
    ret=True
    try:
        msg=MIMEText(Content,'plain','utf-8')          #邮件内容
        msg['From']=formataddr([Whoisme, my_sender])   #括号里的对应发件人邮箱昵称、发件人邮箱账号
        msg['To']=formataddr(["♥",Send_To])   #括号里的对应收件人邮箱昵称、收件人邮箱账号
        msg['Subject']=Subject #邮件的主题，也可以说是标题

        server=smtplib.SMTP(smtp_addr,smtp_port)  #发件人邮箱中的SMTP服务器，端口是25
        server.login(my_sender,my_passwd)    #括号中对应的是发件人邮箱账号、邮箱密码
        server.sendmail(my_sender,[Send_To,],msg.as_string())   #括号中对应的是发件人邮箱账号、收件人邮箱账号、发送邮件
        server.quit()   #这句是关闭连接的意思
    except Exception:   #如果try中的语句没有执行，则会执行下面的ret=False
        ret = False
    return ret

if __name__ == '__main__':
      Send_To=str(sys.argv[1])
      Subject=str(sys.argv[2])
      Content=str(sys.argv[3])
      Status = send_mail(Whoisme, Subject, Content, Send_To)
      print Status
      if Status:
         print("发送邮件成功") #如果发送成功则会返回ok，稍等20秒左右就可以收到邮件
      else:
         print("failed!!!")  #如果发送失败则会返回filed
