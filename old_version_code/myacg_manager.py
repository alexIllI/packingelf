from operation.account_manage import EncryptedAccountManager

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait 
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from selenium.common.exceptions import NoSuchElementException

import os
import sys
from subprocess import CREATE_NO_WINDOW
from configparser import ConfigParser
from enum import Enum

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")

    return os.path.join(base_path, relative_path)

#====================== Enum ===============================
class ReturnType(Enum):
    MULTIPLE_TAB = "MULTIPLE_TAB"
    POPUP_UNSOLVED = "POPUP_UNSOLVED"
    ALREADY_FINISH = "ALREADY_FINISH"
    ORDER_NOT_FOUND = "ORDER_NOT_FOUND"
    ORDER_NOT_FOUND_ERROR = "ORDER_NOT_FOUND_ERROR"
    CHECKBOX_NOT_FOUND = "CHECKBOX_NOT_FOUND"
    CLICKING_CHECKBOX_ERROR = "CLICKING_CHECKBOX_ERROR"
    CLICKING_PRINT_ORDER_ERROR = "CLICKING_PRINT_ORDER_ERROR"
    ORDER_CANCELED = "ORDER_CANCELED"
    STORE_CLOSED = "STORE_CLOSED"
    SWITCH_TAB_ERROR = "SWITCH_TAB_ERROR"
    LOAD_HTML_BODY_ERROR = "LOAD_HTML_BODY_ERROR"
    EXCUTE_PRINT_ERROR = "EXCUTE_PRINT_ERROR"
    CLOSED_TAB_ERROR = "CLOSED_TAB_ERROR"
    SUCCESS = "SUCCESS"
    
class AccountReturnType(Enum):
    SUCCESS = "SUCCESS"
    USERNAME_REPEAT = "USERNAME_REPEAT"
    USERNAME_NOT_FOUND = "USERNAME_NOT_FOUND"
    LOAD_AND_DECRYPT_ERROR = "LOAD_AND_DECRYPT_ERROR"
    ADD_ACCOUNT_ERROR = "ADD_ACCOUNT_ERROR"
    GET_ACCOUNT_INFO_ERROR = "GET_ACCOUNT_INFO_ERROR"
    MODIFY_ACCOUNT_ERROR = "MODIFY_ACCOUNT_ERROR"
    DELETE_ACCOUNT_ERROR = "DELETE_ACCOUNT_ERROR"
    LOGOUT_BTN_NOT_FOUND = "LOGOUT_BTN_NOT_FOUND"
    GET_LOGIN_PAGE_ERROR = "GET_LOGIN_PAGE_ERROR"
    LOGIN_ACCOUNT_ERROR = "LOGIN_ACCOUNT_ERROR"
    LOGIN_PASSWORD_ERROR = "LOGIN_PASSWORD_ERROR"
    LOGIN_BTN_ERROR = "LOGIN_BTN_ERROR"
    WRONG_ACCOUNT_INFO = "WRONG_ACCOUNT_INFO"
    MY_STORE_NOT_FOUND = "MY_STORE_NOT_FOUND"

#====================== Config ===============================
config = ConfigParser()
config.read(resource_path("config.ini"))

#====================== Path ===============================
OUTTER_PATH = os.path.abspath(os.getcwd())
URL = "https://www.myacg.com.tw/login.php?done=http%3A%2F%2Fwww.myacg.com.tw%2Findex.php"

#======================== Chrome Crawler Setting ===============================
options = webdriver.ChromeOptions()
options.add_experimental_option('excludeSwitches', ['enable-logging'])
options.add_experimental_option("excludeSwitches", ["enable-automation"])
options.add_experimental_option('useAutomationExtension', False)
options.add_experimental_option("prefs", {"profile.password_manager_enabled": False, "credentials_enable_service": False})
options.add_experimental_option("detach", True)
options.add_argument('--enable-print-browser')
options.add_argument('--kiosk-printing')
service = Service()
service.creation_flags = CREATE_NO_WINDOW


class MyAcg():
    def __init__(self):
        
        #============== Variables ==============
        self.last = ""
        
        #============== Account ==============
        try:
            self.account_manager = EncryptedAccountManager()
            self.account_manager.load_and_decrypt()
            
            # if there are multiple accounts, change
            account_info = self.account_manager.get_account_by_name("子午計畫")
            account = account_info["account"]
            password = account_info["password"]
        except:
            print("decrypt info ERROR!!")
            return 
        
        #============== Login ==============
        try:
            self.driver = webdriver.Chrome(service=service,options=options)
            self.driver.get(URL)
        except:
            print("error occured when creating webdriver")
            return 
        
        #login account
        try:
            account_element = WebDriverWait(self.driver, config["WebOperation"]["waittime"]).until(
                EC.presence_of_element_located((By.NAME, "account")))
            account_element.clear()
            account_element.send_keys(account)
        except:
            print("can't find 'login account' element, or connection timed out")
            return 
        
        #login password
        try:
            password_element = WebDriverWait(self.driver, config["WebOperation"]["waittime"]).until(
                EC.presence_of_element_located((By.NAME, "password")))
            password_element.clear()
            password_element.send_keys(password)
        except:
            print("can't find 'login password' element, or connection timed out")
            return 
        
        #login button
        try:
            Login_btn = WebDriverWait(self.driver, config["WebOperation"]["waittime"]).until(
                EC.presence_of_element_located((By.XPATH, '//*[@id="form1"]/div/div/div[2]/div[5]/div[1]/a')))
            Login_btn.click()
        except:
            print("can't find 'login button' element, or connection timed out")
            return 

        #find 我的賣場 element and click
        try:
            locate_store = (By.XPATH, '//*[@id="topbar"]/div/ul/li[1]/a')
            Store = WebDriverWait(self.driver, config["WebOperation"]["longerwaittime"]).until(
                EC.presence_of_element_located(locate_store),
                "Can't find my store button")
        except:
            print("我的賣場按鈕連線超時")
            return False

        Store.click()

    #find search bar and search
    def printer(self, order):
        self.using_coupon = "否"
        self.order_establish_date = None
        
        # ================== for test ==================
        # return ["是", "2024-07-01 12:00:00"]
        # ==============================================
        
        if len(self.driver.window_handles) > 1:
            return ReturnType.MULTIPLE_TAB
        
        #check if last one is closed, the popup window had been handled
        try:
            search_bar = self.driver.find_element(By.NAME, 'o_num') #search bar element
            search_bar.clear()
            search_bar.send_keys(order)
            search = self.driver.find_element(By.XPATH, '//*[@id="search_goods"]/div[4]/ul/li[2]/a') #search button element
            search.click()
        except:
            try:
                self.driver.switch_to.window(self.driver.window_handles[0])
                return ReturnType.STORE_CLOSED
            except:
                return ReturnType.POPUP_UNSOLVED
        
        #check if the order exist
        try:
            no_order_wait = self.driver.find_element(By.XPATH, '//*[@id="wrap"]/div[2]/div/div[2]/div/span[2]/a')
            if no_order_wait:
                return ReturnType.ORDER_NOT_FOUND
        except:
            pass
        
        #check if it's canceled
        try:
            self.driver.find_element(By.XPATH, '//*[@id="wrap"]/div[2]/div[2]/div[1]/table/tbody/tr[1]/td[1]/div[1]/div/span[2]')
            return ReturnType.ORDER_CANCELED
        except NoSuchElementException:
            pass
        
        # check if there is closed tag-------------------------------------------
        try:
            self.driver.find_element(By.XPATH, '//*[@id="wrap"]/div[2]/div[2]/div[1]/table/tbody/tr[1]/td[7]/span')
            return ReturnType.STORE_CLOSED
        except NoSuchElementException:
            pass
        try:
            self.driver.find_element(By.XPATH, '//*[@id="wrap"]/div[2]/div[2]/div[1]/table/tbody/tr/td[1]/div[2]/div/span[2]')
            return ReturnType.STORE_CLOSED
        except NoSuchElementException:
            pass
        # ------------------------------------------------------------------------
        
        #check if using coupon
        try:
            # locate print order button as indicator of whether it's finished
            self.driver.find_element(By.XPATH, '//*[@id="wrap"]/div[2]/div[2]/div[1]/table/tbody/tr[1]/td[6]/p')
            self.using_coupon = "是"
            print("using coupon")
        except NoSuchElementException:
            print("not using coupon")
            
        # locate order establishment date
        try:
            self.order_establish_date_element = self.driver.find_element(By.CLASS_NAME, 'order_process_text_orange')
            full_text = self.order_establish_date_element.text
            self.order_establish_date = full_text.split('\n')[-1].strip()
        except:
            # return ReturnType.ORDER_DATE_NOT_FOUND
            print("order establish date not found")
        
        #======================================= TEST RETURN ====================================================
        # try:
        #     no_order = self.driver.find_element(By.XPATH, '//*[@id="wrap"]/div[2]/div/div[2]/div/span[1]')
        #     no_order_text = no_order.text
        #     if no_order_text == "您沒有訂單，趕快到買動漫逛逛吧！":
        #         return ReturnType.ORDER_CANCELED
        # except:
        #     pass
        
        # return ReturnType.SUCCESS
        #=================================================================================================
        
        #等待直到check box出現並勾選
        try:
            checkbox = WebDriverWait(self.driver, config["WebOperation"]["waittime"]).until(
                EC.presence_of_element_located((By.ID, "oid_check_" + order[3:])))
        except:
            return ReturnType.CHECKBOX_NOT_FOUND

        # use Javascript to click checkbox
        try:
            self.driver.execute_script("arguments[0].click();", checkbox)  
        except:
            return ReturnType.CLICKING_CHECKBOX_ERROR
        
        #click print order
        try:
            print_order = self.driver.find_element(By.ID, 'PrintBatch_2')
            print_order.click()
        except:
            return ReturnType.CLICKING_PRINT_ORDER_ERROR

        #測試是否有開啟新分頁
        try:
            self.driver.switch_to.window(self.driver.window_handles[1])
            #測試是否可以handle pop up
            try:
                alert = self.driver.switch_to.alert
                print(f"popup alert showing message: {alert.text}")
                alert.accept()
                self.driver.close()
                self.driver.switch_to.window(self.driver.window_handles[0])
                return ReturnType.STORE_CLOSED
            except:
                pass
        except:
            #測試是否可以handle pop up
            try:
                alert = self.driver.switch_to.alert
                print(f"popup alert showing message: {alert.text}")
                alert.accept()
                # self.driver.execute_script("switchTo().alert().dismiss();")
                return ReturnType.STORE_CLOSED
            except:
                pass
            return ReturnType.SWITCH_TAB_ERROR
        
        #列印出貨單(找出出貨單元素)
        try:
            wait = WebDriverWait(self.driver, config["WebOperation"]["longerwaittime"])
            wait.until(EC.presence_of_element_located((By.TAG_NAME, "body")))
        except:
            return ReturnType.LOAD_HTML_BODY_ERROR
        
        #excute printing
        try:
            self.driver.execute_script('window.print();')
            print("成功列印")
        except:
            return ReturnType.EXCUTE_PRINT_ERROR
        
        #close opend tab
        try:
            self.driver.close()
            self.driver.switch_to.window(self.driver.window_handles[0])
        except:
            return ReturnType.CLOSED_TAB_ERROR
        
        return [self.using_coupon, self.order_establish_date]
    
    def switch_account(self, username):

        #============== Account ==============
        try:
            self.account_manager.load_and_decrypt()
            if username not in self.account_manager.get_all_account_names():
                return AccountReturnType.USERNAME_NOT_FOUND
        except:
            return AccountReturnType.LOAD_AND_DECRYPT_ERROR
        
        try:
            account_info = self.account_manager.get_account_by_name(username)
            self.account = account_info["account"]
            self.password = account_info["password"]
        except:
            return AccountReturnType.GET_ACCOUNT_INFO_ERROR
        
        #============== Login ==============
        if self.driver.current_url != URL:
            try:
                logout_btn = self.driver.find_element(By.XPATH, '/html/body/div[8]/div[3]/div[1]/p[1]/span/a')
                logout_btn.click()
                self.driver.get(URL)
            except:
                return AccountReturnType.GET_LOGIN_PAGE_ERROR
        
        #login account
        try:
            account_element = WebDriverWait(self.driver, config["WebOperation"]["waittime"]).until(
                EC.presence_of_element_located((By.NAME, "account")))
            account_element.clear()
            account_element.send_keys(self.account)
        except:
            return AccountReturnType.LOGIN_ACCOUNT_ERROR
        
        #login password
        try:
            password_element = WebDriverWait(self.driver, config["WebOperation"]["waittime"]).until(
                EC.presence_of_element_located((By.NAME, "password")))
            password_element.clear()
            password_element.send_keys(self.password)
        except:
            return AccountReturnType.LOGIN_PASSWORD_ERROR
        
        #login button
        try:
            Login_btn = WebDriverWait(self.driver, config["WebOperation"]["waittime"]).until(
                EC.presence_of_element_located((By.XPATH, '//*[@id="form1"]/div/div/div[2]/div[5]/div[1]/a')))
            Login_btn.click()
        except:
            return AccountReturnType.LOGIN_BTN_ERROR
        
        try:
            alert = self.driver.switch_to.alert
            alert.accept()
            return AccountReturnType.WRONG_ACCOUNT_INFO
        except:
            pass

        #find 我的賣場 element and click
        try:
            locate_store = (By.XPATH, '//*[@id="topbar"]/div/ul/li[1]/a')
            Store = WebDriverWait(self.driver, config["WebOperation"]["longerwaittime"]).until(
                EC.presence_of_element_located(locate_store),
                "Can't find my store button")
            Store.click()
        except:
            print("我的賣場按鈕連線超時")
            return AccountReturnType.MY_STORE_NOT_FOUND
        
        return AccountReturnType.SUCCESS

    
    def create_account(self, username, account, password):
        try:
            self.account_manager.load_and_decrypt()
            if username in self.account_manager.get_all_account_names():
                return AccountReturnType.USERNAME_REPEAT
        except:
            return AccountReturnType.LOAD_AND_DECRYPT_ERROR
        
        try:
            self.account_manager.add_account(username, {"account": account, "password": password})
            self.account_manager.encrypt_and_save()
            return AccountReturnType.SUCCESS
        except:
            return AccountReturnType.ADD_ACCOUNT_ERROR
        
    def modify_account(self, username, account, password):
        try:
            self.account_manager.load_and_decrypt()
            if username not in self.account_manager.get_all_account_names():
                return AccountReturnType.USERNAME_NOT_FOUND
        except:
            return AccountReturnType.LOAD_AND_DECRYPT_ERROR
        
        try:
            self.account_manager.update_account_by_name(username, {"account": account, "password": password})
            self.account_manager.encrypt_and_save()
            return AccountReturnType.SUCCESS
        except:
            return AccountReturnType.MODIFY_ACCOUNT_ERROR
        
    def delete_account(self, username):
        try:
            self.account_manager.load_and_decrypt()
            if username not in self.account_manager.get_all_account_names():
                return AccountReturnType.USERNAME_NOT_FOUND
        except:
            return AccountReturnType.LOAD_AND_DECRYPT_ERROR
        
        try:
            self.account_manager.delete_account_by_name(username)
            self.account_manager.encrypt_and_save()
            return AccountReturnType.SUCCESS
        except:
            return AccountReturnType.DELETE_ACCOUNT_ERROR
            
    def get_all_account_names(self):
        return self.account_manager.get_all_account_names()
        
    def shut_down(self):
        self.driver.quit()
        print("close webdriver")