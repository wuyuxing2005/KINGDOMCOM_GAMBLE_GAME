package com.local.medievaldice.update;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.core.content.FileProvider;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;

public final class UpdateInstallerPlugin extends GodotPlugin {
    private String pendingApkPath;

    public UpdateInstallerPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "UpdateInstaller";
    }

    @UsedByGodot
    public void installUpdate(String apkPath) {
        pendingApkPath = apkPath;
        runOnUiThread(() -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                    && !getContext().getPackageManager().canRequestPackageInstalls()) {
                Intent settingsIntent = new Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + getContext().getPackageName())
                );
                getActivity().startActivity(settingsIntent);
                return;
            }
            launchPackageInstaller();
        });
    }

    @Override
    public void onMainResume() {
        super.onMainResume();
        if (pendingApkPath != null
                && (Build.VERSION.SDK_INT < Build.VERSION_CODES.O
                || getContext().getPackageManager().canRequestPackageInstalls())) {
            runOnUiThread(this::launchPackageInstaller);
        }
    }

    private void launchPackageInstaller() {
        if (pendingApkPath == null) {
            return;
        }
        File apkFile = new File(pendingApkPath);
        Uri apkUri = FileProvider.getUriForFile(
                getContext(),
                getContext().getPackageName() + ".fileprovider",
                apkFile
        );
        pendingApkPath = null;
        Intent installIntent = new Intent(Intent.ACTION_VIEW);
        installIntent.setDataAndType(apkUri, "application/vnd.android.package-archive");
        installIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        getActivity().startActivity(installIntent);
    }
}
