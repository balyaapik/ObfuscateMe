package com.example.obfuscatemefixture;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;

public class MainActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
    }

    public void xmlClicked(View view) {
        TextView label = findViewById(R.id.status);
        label.setText("Android 14 fixture OK");
    }
}
