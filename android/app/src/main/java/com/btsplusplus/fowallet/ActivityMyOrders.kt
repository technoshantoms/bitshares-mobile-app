package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabItem
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.View
import android.view.animation.OvershootInterpolator
import bitshares.Promise
import bitshares.SettingManager
import com.btsplusplus.fowallet.kline.TradingPair
import kotlinx.android.synthetic.main.activity_my_orders.*
import org.json.JSONArray
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityMyOrders : BtsppActivity() {


    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private lateinit var _full_account_data: JSONObject
    private lateinit var _tradeHistory: JSONArray
    private var _tradingPair: TradingPair? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_my_orders)

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _full_account_data = args.getJSONObject("full_account_data")
        _tradeHistory = args.getJSONArray("trade_history")
        _tradingPair = args.opt("tradingPair") as? TradingPair

        //  事件 - 返回
        layout_back_from_my_orders.setOnClickListener { finish() }

        setFullScreen()

        //  初始化UI
        if (!SettingManager.sharedSettingManager().isAppEnableModuleGridBots()) {
            tablayout_of_my_orders.removeTabAt(3)   //  grid orders
        }

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_my_orders
        view_pager = view_pager_of_my_orders

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()

        //  事件 - 创建网格
        set_create_bots_button_status(visible = false)
    }

    private fun set_create_bots_button_status(visible: Boolean) {
        if (visible) {
            btn_create_bots.visibility = View.VISIBLE
            btn_create_bots.setOnClickListener {
                val result_promise = Promise()
                goTo(ActivityBotsCreate::class.java, true, args = JSONObject().apply {
                    put("result_promise", result_promise)
                })
                result_promise.then { dirty ->
                    //  刷新
                    if (dirty != null && dirty as Boolean) {
                        for (frag in fragmens) {
                            if (frag is FragmentBotsManager) {
                                frag.queryMyBotsList(full_account_data = _full_account_data)
                                break
                            }
                        }
                    }
                    return@then null
                }
            }
        } else {
            btn_create_bots.visibility = View.INVISIBLE
            btn_create_bots.setOnClickListener(null)
        }
    }

    private fun setViewPager() {
        view_pager!!.adapter = ViewPagerAdapter(super.getSupportFragmentManager(), fragmens)
        val f: Field = ViewPager::class.java.getDeclaredField("mScroller")
        f.isAccessible = true
        val vpc: ViewPagerScroller = ViewPagerScroller(view_pager!!.context, OvershootInterpolator(0.6f))
        f.set(view_pager, vpc)
        vpc.duration = 700

        view_pager!!.setOnPageChangeListener(object : ViewPager.OnPageChangeListener {
            override fun onPageScrollStateChanged(state: Int) {
            }

            override fun onPageScrolled(position: Int, positionOffset: Float, positionOffsetPixels: Int) {
            }

            override fun onPageSelected(position: Int) {
                println(position)
                tablayout!!.getTabAt(position)!!.select()
            }
        })
    }

    private fun setFragments() {
        fragmens.add(FragmentOrderCurrent().initialize(JSONObject().apply {
            put("full_account_data", _full_account_data)
            put("tradingPair", _tradingPair)
            put("filter", false)
        }))
        fragmens.add(FragmentOrderHistory().initialize(JSONObject().apply {
            put("data", _tradeHistory)
        }))
        fragmens.add(FragmentOrderHistory().initialize(JSONObject().apply {
            put("isSettlementsOrder", true)
        }))
        if (SettingManager.sharedSettingManager().isAppEnableModuleGridBots()) {
            fragmens.add(FragmentBotsManager().initialize(JSONObject().apply {
                put("full_account_data", _full_account_data)
            }))
        }
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                val pos = tab.position
                view_pager!!.setCurrentItem(pos, true)
                fragmens[pos].let {
                    set_create_bots_button_status(it is FragmentBotsManager)
                    if (it is FragmentOrderCurrent) {
                        it.onControllerPageChanged()
                    } else if (it is FragmentOrderHistory) {
                        it.querySettlementOrders(full_account_data = _full_account_data)
                    } else if (it is FragmentBotsManager) {
                        it.queryMyBotsList(full_account_data = _full_account_data)
                    }
                }
            }

            override fun onTabUnselected(tab: TabLayout.Tab) {
                //tab未被选择的时候回调
            }

            override fun onTabReselected(tab: TabLayout.Tab) {
                //tab重新选择的时候回调
            }
        })
    }


}
