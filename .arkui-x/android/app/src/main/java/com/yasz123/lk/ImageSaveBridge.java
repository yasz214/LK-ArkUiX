package com.yasz123.lk;

import android.content.ContentResolver;
import android.content.Context;
import android.net.Uri;
import android.util.Base64;
import android.util.Log;

import java.io.OutputStream;

import ohos.ace.adapter.capability.bridge.BridgePlugin;
import ohos.ace.adapter.capability.bridge.IMessageListener;


public class ImageSaveBridge extends BridgePlugin implements IMessageListener {
    private static final String TAG = "ImageSaveBridge";
    private final Context context;

    public ImageSaveBridge(Context context, String name, int instanceId) {
        super(context, name, instanceId);
        this.context = context;
        setMessageListener(this);
        Log.i(TAG, "ImageSaveBridge 初始化完成, name=" + name);
    }

    
    @Override
    public Object onMessage(Object data) {
        Log.i(TAG, "收到 ArkTS 消息");
        try {
            String message = (String) data;

            
            int separatorIdx = message.indexOf("||");
            if (separatorIdx == -1) {
                Log.e(TAG, "消息格式错误: 缺少 || 分隔符");
                return "error:消息格式错误";
            }

            String uriStr = message.substring(0, separatorIdx);
            String base64Data = message.substring(separatorIdx + 2);

            Log.i(TAG, "目标URI: " + uriStr);
            Log.i(TAG, "Base64数据长度: " + base64Data.length());

            
            byte[] imageBytes = Base64.decode(base64Data, Base64.DEFAULT);
            Log.i(TAG, "解码后字节数: " + imageBytes.length);

            
            Uri targetUri = Uri.parse(uriStr);
            ContentResolver resolver = context.getContentResolver();
            OutputStream os = resolver.openOutputStream(targetUri);

            if (os == null) {
                Log.e(TAG, "openOutputStream 返回 null");
                return "error:无法打开输出流";
            }

            os.write(imageBytes);
            os.flush();
            os.close();

            Log.i(TAG, "图片写入成功! 字节数=" + imageBytes.length);
            return "ok";

        } catch (Exception e) {
            Log.e(TAG, "图片保存异常: " + e.getMessage(), e);
            return "error:" + e.getMessage();
        }
    }

    @Override
    public void onMessageResponse(Object data) {
        Log.i(TAG, "消息响应: " + data);
    }
}
