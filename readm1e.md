🚀 KẾ HOẠCH GO-LIVE: FRESHKEEP MVP (v1.0)
I. MỤC TIÊU CHIẾN LƯỢC
Mục tiêu: Đưa ứng dụng lên Google Play Store (Production) trong vòng 3-4 tuần.
Đối tượng: Người dùng Việt Nam (Gia đình, nội trợ).
Mô hình: Miễn phí có giới hạn (Freemium) để kiểm soát chi phí API.
II. LỘ TRÌNH TRIỂN KHAI (4 SPRINT)
🔴 SPRINT 1: BẢO MẬT & BACKEND (Quan trọng nhất)
Mục tiêu: Loại bỏ API Key khỏi App, chuyển sang gọi qua Server trung gian.
Thiết lập Firebase Cloud Functions:
Cài đặt Node.js và Firebase CLI.
Khởi tạo Functions trong dự án freshkeep-db.
Viết API Wrapper (Node.js):
Viết hàm analyzeImage: Nhận ảnh từ App -> Gọi Gemini (bằng Key bí mật trên server) -> Trả kết quả về App.
Viết hàm scanReceipt: Tương tự cho hóa đơn.
Refactor Flutter Code:
Sửa AiService: Thay vì gọi google_generative_ai trực tiếp, đổi sang dùng FirebaseFunctions.instance.httpsCallable(...).
Cấu hình App Check (Optional nhưng nên làm):
Đăng ký SHA-256 fingerprint của App với Firebase để chặn các request giả mạo từ bên ngoài.
🟡 SPRINT 2: QUẢN LÝ NGƯỜI DÙNG & GIỚI HẠN (QUOTA)
Mục tiêu: Ngăn chặn spam, giới hạn mỗi người chỉ được scan 5 lần/ngày.
Tích hợp Đăng nhập (Authentication):
Bật Google Sign-In (Nhanh, uy tín, không cần xác thực SMS tốn kém).
Tạo màn hình Login đơn giản (hoặc hiện Dialog yêu cầu login khi bấm nút Scan).
Logic Đếm lượt dùng (Rate Limiting):
Tạo Collection user_stats trên Firestore.
Logic: Mỗi lần gọi Cloud Function thành công -> Tăng biến scan_count của user đó lên 1.
Chặn: Nếu scan_count > 5 -> Server trả về lỗi "Hết lượt miễn phí".
Reset Quota:
Dùng Scheduled Functions (Cronjob) để reset scan_count về 0 vào 00:00 mỗi ngày.
🟢 SPRINT 3: CHUẨN HÓA & PHÁP LÝ (Store Requirements)
Mục tiêu: Đáp ứng quy định của Google để không bị từ chối (Reject).
Chính sách bảo mật (Privacy Policy):
Tạo trang web đơn giản (dùng Notion/Google Sites) ghi rõ: "App dùng Camera để phân tích thực phẩm, không lưu ảnh người dùng trái phép...".
Lấy link đó dán vào Google Play Console.
Tính năng "Xóa tài khoản" (Bắt buộc):
Thêm nút "Delete Account" trong phần Cài đặt.
Logic: Xóa user khỏi Auth và xóa dữ liệu trong Firestore.
Splash Screen & Icon:
Tạo App Icon chuẩn (Android Adaptive Icon).
Tạo màn hình chào (Splash Screen) có logo FreshKeep.
Xử lý Offline:
Khi mất mạng: Hiện thông báo đẹp "Vui lòng kiểm tra kết nối" thay vì crash app.
🔵 SPRINT 4: PHÁT HÀNH (STORE LISTING)
Mục tiêu: Đẩy App lên cửa hàng.
Google Play Console:
Tạo tài khoản Developer ($25 trọn đời).
Tạo App mới: "FreshKeep - Tủ lạnh thông minh".
Bộ ảnh Marketing (Assets):
Chụp 5-7 ảnh màn hình (Screenshots) đẹp (dùng Canva ghép vào khung điện thoại).
Ảnh Feature Graphic (1024x500).
Viết mô tả ngắn (80 ký tự) và mô tả dài chuẩn SEO.
Internal Testing:
Build file .aab (Android App Bundle).
Upload lên nhánh "Internal Testing".
Mời 5-10 người quen tải về test thử.
Production Review:
Gửi xét duyệt (Review). Chờ 3-7 ngày.
III. CHECKLIST KỸ THUẬT (DÀNH CHO DEV)
1. Phần Flutter (Client)
[ ] Xóa toàn bộ API Key hard-code trong main.dart hoặc .env.
[ ] Cài đặt firebase_auth và google_sign_in.
[ ] Cài đặt cloud_functions.
[ ] Thay thế AiService cũ bằng CloudFunctionsService.
[ ] Thêm nút "Đăng nhập bằng Google".
[ ] Thêm màn hình "Settings" có nút Xóa tài khoản.
[ ] Tạo file flutter_native_splash.yaml để sinh Splash Screen.
[ ] Chạy lệnh flutter build appbundle --release.
2. Phần Firebase (Serverless)
[ ] Nâng cấp Firebase lên gói Blaze (Pay as you go).
Lưu ý: Cloud Functions bắt buộc gói Blaze, nhưng có hạn mức miễn phí (2 triệu lượt gọi/tháng). Bạn sẽ chưa mất tiền ngay đâu.
[ ] Deploy Function analyzeFood (Node.js).
[ ] Deploy Function resetDailyQuota (Node.js).
[ ] Cấu hình Firestore Rules: Chỉ cho phép User đọc/ghi dữ liệu của chính mình (request.auth.uid == userId).
IV. DỰ TOÁN CHI PHÍ VẬN HÀNH (THÁNG ĐẦU)
Hạng mục
Chi phí ước tính
Ghi chú
Google Play Dev
$25 (Khoảng 600k VNĐ)
Phí 1 lần duy nhất trọn đời.
Firebase (Blaze)
$0
Miễn phí 2M lượt gọi Function, 1GB data.
Gemini API
$0 - $5
Free Tier (15 RPM) đủ cho MVP. Nếu vượt quá sẽ tính phí rẻ.
Domain (Optional)
200k - 300k VNĐ
Nếu muốn làm Landing Page xịn.

V. RỦI RO & PHƯƠNG ÁN (BACKUP PLAN)
Rủi ro: Google Play từ chối duyệt vì "App sơ sài".
Giải pháp: Đảm bảo phần UI đẹp (như bản update cuối cùng), mô tả chức năng rõ ràng, không crash.
Rủi ro: Chi phí Gemini tăng đột biến.
Giải pháp: Thiết lập "Budget Alert" trong Google Cloud Console. Cài đặt giới hạn cứng (Quota limit) để API tự ngắt nếu tiêu hết $10/tháng.


firebase functions:config:set gemini.key="AIzaSyCkbdJ6DYoYoqf3QFGaISP_goJX3Nz_ROM"
firebase deploy --only functions