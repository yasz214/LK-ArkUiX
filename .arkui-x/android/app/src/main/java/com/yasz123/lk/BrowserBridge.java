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
            context.startActivity(intent);

            Log.i(TAG, "已启动外部浏览器");
            return "ok";

        } catch (Exception e) {
            Log.e(TAG, "打开浏览器异常: " + e.getMessage(), e);
            return "error:" + e.getMessage();
        }
    }

    @Override
    public void onMessageResponse(Object data) {
        Log.i(TAG, "消息响应: " + data);
    }
}
