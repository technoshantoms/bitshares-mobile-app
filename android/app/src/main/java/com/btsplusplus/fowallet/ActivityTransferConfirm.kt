package com.btsplusplus.fowallet

import android.content.Intent
import android.os.Bundle
import android.widget.TextView
import bitshares.OrgUtils
import bitshares.Promise
import kotlinx.android.synthetic.main.activity_transfer_confirm.*

class ActivityTransferConfirm : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_transfer_confirm)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val transfer_args = btspp_args_as_JSONObject()
        val result_promise = transfer_args.opt("result_promise") as? Promise

        //  设置页面的6个字段
        val asset = transfer_args.getJSONObject("asset")
        val asset_symbol = asset.getString("symbol")
        val kAmount = OrgUtils.formatFloatValue(transfer_args.getDouble("kAmount"), asset.getInt("precision"))
        val fee_asset = transfer_args.getJSONObject("fee_asset")
        val fee_asset_symbol = fee_asset.getString("symbol")
        val kFeeCost = OrgUtils.formatFloatValue(transfer_args.getDouble("kFeeCost"), fee_asset.getInt("precision"))
        findViewById<TextView>(R.id.txt_from).text = transfer_args.getJSONObject("from").getString("name")
        findViewById<TextView>(R.id.txt_to).text = transfer_args.getJSONObject("to").getString("name")
        findViewById<TextView>(R.id.txt_amount).text = "$kAmount$asset_symbol"
        findViewById<TextView>(R.id.txt_memo).text = transfer_args.optString("kMemo", "")
        findViewById<TextView>(R.id.txt_fee).text = "$kFeeCost$fee_asset_symbol"

        //  事件：返回
        layout_back_from_transfer_confirmation.setOnClickListener {
            if (result_promise != null) {
                result_promise.resolve(false)
                finish()
            } else {
                val intent = Intent()
                //  返回结果：取消
                setResult(0, intent)
                finish()
            }
        }

        //  事件：确认
        findViewById<TextView>(R.id.submit_of_tc).setOnClickListener {
            if (result_promise != null) {
                result_promise.resolve(true)
                finish()
            } else {
                val intent = Intent()
                //  返回结果：确认转账
                setResult(1, intent)
                finish()
            }
        }
    }
}
