package com.yasz123.lk;

import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import ohos.stage.ability.adapter.StageActivity;


public class EntryEntryAbilityActivity extends StageActivity {
    private static final String TAG = "LK-Activity";
    private ImageSaveBridge imageSaveBridge;
    private WifiBridge wifiBridge;
    private FontBridge fontBridge;
    private BrowserBridge browserBridge;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.i(TAG, "EntryEntryAbilityActivity onCreate 开始");

        
        setupImmersiveStatusBar();

        setInstanceName("com.yasz123.lk:entry:EntryAbility:");
        super.onCreate(savedInstanceState);

        
        try {
            imageSaveBridge = new ImageSaveBridge(this, "ImageSaveBridge", getInstanceId());
            Log.i(TAG, "ImageSaveBridge 注册成功");
        } catch (Exception e) {
            Log.e(TAG, "ImageSaveBridge 注册失败", e);
        }

        try {
            wifiBridge = new WifiBridge(this, "WifiBridge", getInstanceId());
            Log.i(TAG, "WifiBridge 注册成功");
        } catch (Exception e) {
            Log.e(TAG, "WifiBridge 注册失败", e);
        }

        try {
            fontBridge = new FontBridge(this, "FontBridge", getInstanceId());
            Log.i(TAG, "FontBridge 注册成功");
        } catch (Exception e) {
            Log.e(TAG, "FontBridge 注册失败", e);
        }

        try {
            browserBridge = new BrowserBridge(this, "BrowserBridge", getInstanceId());
            Log.i(TAG, "BrowserBridge 注册成功");
        } catch (Exception e) {
            Log.e(TAG, "BrowserBridge 注册失败", e);
        }

        Log.i(TAG, "EntryEntryAbilityActivity onCreate 完成");
    }

    
    private void setupImmersiveStatusBar() {
        try {
            Window window = getWindow();
            if (window == null) return;

            
            window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
            window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION);

            
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);

            
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);

            
            View decorView = window.getDecorView();
            int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;

            
            boolean isDarkMode = isDarkModeEnabled();
            if (!isDarkMode) {
                
                flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
                }
            }
            

            decorView.setSystemUiVisibility(flags);

            Log.i(TAG, "沉浸式状态栏设置完成, isDarkMode=" + isDarkMode);
        } catch (Exception e) {
            Log.e(TAG, "设置沉浸式状态栏失败", e);
        }
    }

    
    private boolean isDarkModeEnabled() {
        int nightMode = getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
        return nightMode == Configuration.UI_MODE_NIGHT_YES;
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);

        
        try {
            boolean isDarkMode = (newConfig.uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
            View decorView = getWindow().getDecorView();
            int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;

            if (!isDarkMode) {
                flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
                }
            }

            decorView.setSystemUiVisibility(flags);
            Log.i(TAG, "主题切换，重新配置状态栏, isDarkMode=" + isDarkMode);
        } catch (Exception e) {
            Log.e(TAG, "主题切换时配置状态栏失败", e);
        }
    }
}
