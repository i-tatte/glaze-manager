from firebase_admin import initialize_app
from firebase_functions import options

initialize_app()
options.set_global_options(region="us-central1")

# Firebase Functions ランタイムは main モジュールのトップレベル属性から
# デコレータ付き関数を発見する。サブモジュールからインポートすれば
# main.issue_transfer_code 等としてランタイムに公開される。
from transfer_codes import issue_transfer_code, redeem_transfer_code  # noqa: E402, F401
from image_pipeline import process_uploaded_image  # noqa: E402, F401
