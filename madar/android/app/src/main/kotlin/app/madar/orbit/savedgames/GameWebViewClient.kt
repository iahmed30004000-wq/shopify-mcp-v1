package app.madar.orbit.savedgames

import android.annotation.TargetApi
import android.graphics.Bitmap
import android.net.http.SslError
import android.os.Build
import android.os.Message
import android.view.KeyEvent
import android.webkit.ClientCertRequest
import android.webkit.HttpAuthHandler
import android.webkit.RenderProcessGoneDetail
import android.webkit.SafeBrowsingResponse
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import java.lang.ref.WeakReference

/**
 * A game WebView's client: the client the webview_flutter_android plugin
 * installed ([inner] – navigation policy, page / progress / error / auth /
 * SSL callbacks to Dart) with every overridable callback passed through
 * unchanged, except that a dead renderer (crashed, or killed for memory) is
 * reported to Dart ([SavedGamesPlugin.onRendererGone]) and handled (`true`):
 * a client that answers `false` there – WebViewClient's default, which the
 * plugin keeps – makes Android kill the whole app.
 *
 * The plugin's client hands itself and the view to Dart, so calling it with
 * the same arguments keeps its Dart pairing (and its synchronous
 * `shouldOverrideUrlLoading` answer, which Dart sets on that instance).
 * Framework-internal callbacks outside the SDK keep WebViewClient's default,
 * which only routes to the public callbacks below or back to the view.
 *
 * Parameters are nullable on purpose: WebView does pass null (`favicon`
 * always may be), and a non-null Kotlin parameter would throw before the
 * plugin ever saw the call.
 *
 * The [SavedGamesPlugin] is held weakly: the WebView (which holds this
 * client) must never keep an engine's plugin alive.
 */
internal class GameWebViewClient(
    val inner: WebViewClient,
    val webViewId: Long,
    owner: SavedGamesPlugin,
) : WebViewClient() {
    private val owner = WeakReference(owner)

    // ------------------------------------------------------ the one change ----

    override fun onRenderProcessGone(view: WebView?, detail: RenderProcessGoneDetail?): Boolean {
        // The plugin's own answer (false: kill the app) is superseded.
        inner.onRenderProcessGone(view, detail)
        owner.get()?.onRendererGone(webViewId, view)
        return true
    }

    // --------------------------------------------------------- navigation ----

    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean =
        inner.shouldOverrideUrlLoading(view, request)

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean =
        inner.shouldOverrideUrlLoading(view, url)

    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        inner.onPageStarted(view, url, favicon)
    }

    override fun onPageCommitVisible(view: WebView?, url: String?) {
        inner.onPageCommitVisible(view, url)
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        inner.onPageFinished(view, url)
    }

    override fun onLoadResource(view: WebView?, url: String?) {
        inner.onLoadResource(view, url)
    }

    override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
        inner.doUpdateVisitedHistory(view, url, isReload)
    }

    override fun onFormResubmission(view: WebView?, dontResend: Message?, resend: Message?) {
        inner.onFormResubmission(view, dontResend, resend)
    }

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onTooManyRedirects(view: WebView?, cancelMsg: Message?, continueMsg: Message?) {
        inner.onTooManyRedirects(view, cancelMsg, continueMsg)
    }

    override fun onScaleChanged(view: WebView?, oldScale: Float, newScale: Float) {
        inner.onScaleChanged(view, oldScale, newScale)
    }

    // ----------------------------------------------------------- requests ----

    override fun shouldInterceptRequest(view: WebView?, request: WebResourceRequest?): WebResourceResponse? =
        inner.shouldInterceptRequest(view, request)

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun shouldInterceptRequest(view: WebView?, url: String?): WebResourceResponse? =
        inner.shouldInterceptRequest(view, url)

    // ------------------------------------------------------------- errors ----

    override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
        inner.onReceivedError(view, request, error)
    }

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
        inner.onReceivedError(view, errorCode, description, failingUrl)
    }

    override fun onReceivedHttpError(view: WebView?, request: WebResourceRequest?, errorResponse: WebResourceResponse?) {
        inner.onReceivedHttpError(view, request, errorResponse)
    }

    override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
        inner.onReceivedSslError(view, handler, error)
    }

    /** API 27+: WebView never calls it before; the plugin keeps the default (interstitial). */
    @TargetApi(Build.VERSION_CODES.O_MR1)
    override fun onSafeBrowsingHit(view: WebView?, request: WebResourceRequest?, threatType: Int, callback: SafeBrowsingResponse?) {
        inner.onSafeBrowsingHit(view, request, threatType, callback)
    }

    // --------------------------------------------------------- auth / keys ----

    override fun onReceivedHttpAuthRequest(view: WebView?, handler: HttpAuthHandler?, host: String?, realm: String?) {
        inner.onReceivedHttpAuthRequest(view, handler, host, realm)
    }

    override fun onReceivedClientCertRequest(view: WebView?, request: ClientCertRequest?) {
        inner.onReceivedClientCertRequest(view, request)
    }

    override fun onReceivedLoginRequest(view: WebView?, realm: String?, account: String?, args: String?) {
        inner.onReceivedLoginRequest(view, realm, account, args)
    }

    override fun shouldOverrideKeyEvent(view: WebView?, event: KeyEvent?): Boolean =
        inner.shouldOverrideKeyEvent(view, event)

    override fun onUnhandledKeyEvent(view: WebView?, event: KeyEvent?) {
        inner.onUnhandledKeyEvent(view, event)
    }
}
