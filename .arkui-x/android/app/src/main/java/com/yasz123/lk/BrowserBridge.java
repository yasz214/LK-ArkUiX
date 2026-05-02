package com.yasz123.lk;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import ohos.ace.adapter.capability.bridge.BridgePlugin;
import ohos.ace.adapter.capability.bridge.IMessageListener;


public class BrowserBridge extends BridgePlugin implements IMessageListener {
    private static final String TAG = "BrowserBridge";
    private final Context context;

    public BrowserBridge(Context context, String name, int instanceId) {
        super(context, name, instanceId);
        this.context = context;
        setMessageListener(this);
        Log.i(TAG, "BrowserBridge 初始化完成, name=" + name);
    }

    
    @Override
    public Object onMessage(Object data) {
        Log.i(TAG, "收到 ArkTS 消息");
        try {
            String url = (String) data;
            Log.i(TAG, "打开URL: " + url);

            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

            
            if (intent.resolveActivity(context.getPackageManager()) != null) {
                context.startActivity(intent);
                Log.i(TAG, "已启动外部应用");
                return "ok";
            } else {
                Log.w(TAG, "没有应用可处理该 URL: " + url);
                
                if (url.startsWith("tencent://") || url.startsWith("mqqwpa://")) {
                    
                    String qqNum = extractQQNumber(url);
                    if (qqNum != null) {
                        String webUrl = "https://wpa.qq.com/msgrd?v=3&uin=" + qqNum + "&site=qq&menu=yes";
                        Log.i(TAG, "QQ 协议不可用，回退 Web 链接: " + webUrl);
                        Intent webIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(webUrl));
                        webIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        context.startActivity(webIntent);
                        return "ok";
                    }
                }
                return "error:no_app_to_handle";
            }

        } catch (Exception e) {
            Log.e(TAG, "打开浏览器异常: " + e.getMessage(), e);
            return "error:" + e.getMessage();
        }
    }

    
    private String extractQQNumber(String url) {
        try {
            
            Uri uri = Uri.parse(url);
            String uin = uri.getQueryParameter("uin");
            if (uin != null && !uin.isEmpty()) {
                return uin;
            }
        } catch (Exception e) {
            Log.w(TAG, "提取 QQ 号失败: " + e.getMessage());
        }
        return null;
    }

    @Override
    public void onMessageResponse(Object data) {
        Log.i(TAG, "消息响应: " + data);
    }
}
