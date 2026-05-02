package com.yasz123.lk;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

import ohos.ace.adapter.capability.bridge.BridgePlugin;
import ohos.ace.adapter.capability.bridge.IMessageListener;


public class FontBridge extends BridgePlugin implements IMessageListener {
    private static final String TAG = "FontBridge";
    private final Context context;

    public FontBridge(Context context, String name, int instanceId) {
        super(context, name, instanceId);
        this.context = context;
        setMessageListener(this);
        Log.i(TAG, "FontBridge 初始化完成, name=" + name);
    }

    
    @Override
    public Object onMessage(Object data) {
        Log.i(TAG, "收到请求");
        try {
            String message = (String) data;

            int separatorIdx = message.indexOf("||");
            if (separatorIdx == -1) {
                Log.e(TAG, "消息格式错误: 缺少 || 分隔符");
                return "error:消息格式错误";
            }

            String command = message.substring(0, separatorIdx);
            String param = message.substring(separatorIdx + 2);

            
            if ("queryName".equals(command)) {
                return queryDisplayName(param);
            }

            
            return copyFontFile(command, param);

        } catch (Exception e) {
            Log.e(TAG, "请求处理异常: " + e.getMessage(), e);
            return "error:" + e.getMessage();
        }
    }

    
    private String queryDisplayName(String uriStr) {
        try {
            Uri uri = Uri.parse(uriStr);
            ContentResolver resolver = context.getContentResolver();
            Cursor cursor = resolver.query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null);
            if (cursor != null) {
                try {
                    if (cursor.moveToFirst()) {
                        int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                        if (nameIndex >= 0) {
                            String displayName = cursor.getString(nameIndex);
                            Log.i(TAG, "查询到文件名: " + displayName);
                            return "name:" + displayName;
                        }
                    }
                } finally {
                    cursor.close();
                }
            }
            Log.w(TAG, "无法查询文件名");
            return "error:无法查询文件名";
        } catch (Exception e) {
            Log.e(TAG, "查询文件名异常: " + e.getMessage(), e);
            return "error:" + e.getMessage();
        }
    }

    
    private String copyFontFile(String uriStr, String targetPath) {
        Log.i(TAG, "源URI: " + uriStr);
        Log.i(TAG, "目标路径: " + targetPath);

        try {
            Uri sourceUri = Uri.parse(uriStr);
            ContentResolver resolver = context.getContentResolver();
            InputStream is = resolver.openInputStream(sourceUri);

            if (is == null) {
                Log.e(TAG, "openInputStream 返回 null");
                return "error:无法打开输入流";
            }

            
            File targetFile = new File(targetPath);
            File parentDir = targetFile.getParentFile();
            if (parentDir != null && !parentDir.exists()) {
                parentDir.mkdirs();
            }

            
            FileOutputStream fos = new FileOutputStream(targetFile);
            byte[] buffer = new byte[8192];
            int bytesRead;
            long totalBytes = 0;
            while ((bytesRead = is.read(buffer)) != -1) {
                fos.write(buffer, 0, bytesRead);
                totalBytes += bytesRead;
            }
            fos.flush();
            fos.close();
            is.close();

            Log.i(TAG, "字体文件复制成功! 总字节数=" + totalBytes);
            return "ok";
        } catch (Exception e) {
            Log.e(TAG, "字体复制异常: " + e.getMessage(), e);
            return "error:" + e.getMessage();
        }
    }

    @Override
    public void onMessageResponse(Object data) {
        Log.i(TAG, "消息响应: " + data);
    }
}
