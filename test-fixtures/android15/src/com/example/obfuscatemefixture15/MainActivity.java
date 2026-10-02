package com.example.obfuscatemefixture15;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import java.lang.reflect.Method;

public class MainActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        exerciseReflectionSentinel();
    }

    public void xmlClicked(View view) {
        TextView label = findViewById(R.id.status);
        label.setText("Android 15 fixture OK");
    }

    private void exerciseReflectionSentinel() {
        try {
            Class<?> type = Class.forName(
                    "com.example.obfuscatemefixture15.ReflectiveTarget"
            );
            Method method = type.getDeclaredMethod("reflectedEntry");
            method.invoke(type.getDeclaredConstructor().newInstance());
        } catch (ReflectiveOperationException ignored) {
            // The fixture only verifies that these reflection strings survive
            // decode/rebuild and are visible to ObfuscateMe keep-rule analysis.
        }
    }
}
