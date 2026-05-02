package com.yasz123.lk;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.util.Log;

import ohos.ace.adapter.capability.bridge.BridgePlugin;
import ohos.ace.adapter.capability.bridge.IMessageListener;


public class WifiBridge extends BridgePlugin implements IMessageListener {
    private static final String TAG = "WifiBridge";
    private final Context context;

    public WifiBridge(Context context, String name, int instanceId) {
        super(context, name, instanceId);
        this.context = context;
        setMessageListener(this);
        Log.i(TAG, "WifiBridge 初始化完成");
    }

    @Override
    public Object onMessage(Object data) {
        String command = String.valueOf(data);
        Log.i(TAG, "收到消息: " + command);

        if ("check".equals(command)) {
            return checkWifiConnected() ? "connected" : "disconnected";
        }

        return "unknown_command";
    }

    @Override
    public void onMessageResponse(Object data) {
        Log.i(TAG, "消息响应: " + data);
    }

    
    private boolean checkWifiConnected() {
        try {
            ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) {
                Log.w(TAG, "ConnectivityManager 不可用");
                return false;
            }

            Network activeNetwork = cm.getActiveNetwork();
            if (activeNetwork == null) {
                Log.i(TAG, "无活跃网络");
                return false;
            }

            NetworkCapabilities caps = cm.getNetworkCapabilities(activeNetwork);
            if (caps == null) {
                Log.i(TAG, "无法获取网络能力");
                return false;
            }

            boolean isWifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI);
            Log.i(TAG, "WiFi 连接状态: " + isWifi);
            return isWifi;
        } catch (Exception e) {
            Log.e(TAG, "检测 WiFi 失败", e);
            return false;
        }
    }
}
