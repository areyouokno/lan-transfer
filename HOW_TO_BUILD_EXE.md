# 用 GitHub Actions 编译出 Windows exe —— 完整操作步骤

不需要在本机装任何东西，只需要一个 GitHub 账号。预计耗时：上传代码 5 分钟 + 云端编译等待 5-8 分钟。

## 第一步：注册/登录 GitHub

打开 https://github.com ，如果没有账号先注册一个（免费）。

## 第二步：创建一个新仓库

1. 右上角点 `+` → `New repository`
2. 仓库名随便起，比如 `lan-transfer`
3. 选择 `Private`（私有，不想让外部人看到代码）或 `Public` 都可以
4. **不要**勾选"Add a README file"（因为我们要上传自己的文件）
5. 点 `Create repository`

## 第三步：上传代码（网页直接拖拽，不需要命令行）

创建仓库后，页面上会有 `uploading an existing file` 的链接，点击它，进入上传页面。

把解压后的 `lan_transfer` 文件夹里的**所有内容**（包括隐藏的 `.github` 文件夹）拖拽到网页的上传区域。

**注意**：网页拖拽上传有时候不能正确识别 `.github/workflows/build-windows.yml` 这种嵌套在隐藏文件夹里的文件。如果发现上传后看不到 `.github` 目录，最简单的解决方法是改用 GitHub Desktop 客户端（见下方"如果网页上传失败"）。

上传完成后，在底部填写提交信息（随便写，比如"初始提交"），点击 `Commit changes`。

## 第四步：触发编译

1. 进入仓库页面，点击顶部的 `Actions` 标签
2. 应该能看到一个名为 `Build Windows EXE` 的工作流
   - 如果第三步上传成功，这个工作流会在你提交代码后**自动开始运行**（黄色圆点=正在跑，绿色勾=成功，红色叉=失败）
   - 如果没有自动运行，点进 `Build Windows EXE` → 右侧 `Run workflow` 按钮 → 选择 `main` 分支 → 点击绿色的 `Run workflow`
3. 等待 5-8 分钟（云端要下载 Flutter SDK、装 Windows 桌面工具链、编译），期间可以刷新页面看进度

## 第五步：下载编译好的exe

1. 编译成功后（绿色勾），点进这次运行记录
2. 往下滚动到 `Artifacts` 区域
3. 点击 `lan_transfer_windows` 即可下载一个 zip
4. 解压后里面是 `lan_transfer.exe` 加上一堆 `.dll` 文件——**这些文件必须放在同一个文件夹里**，不能只拷走 exe，否则运行会报错"缺少 xxx.dll"

## 如果网页上传失败：用 GitHub Desktop（推荐，更稳）

1. 下载安装 [GitHub Desktop](https://desktop.github.com/)
2. 用你的 GitHub 账号登录
3. `File` → `Add local repository` → 选择解压后的 `lan_transfer` 文件夹
4. 如果提示"这不是一个git仓库，是否创建一个"，点确认创建
5. 左下角填写提交信息，点击 `Commit to main`
6. 点击右上角 `Publish repository`（如果还没在GitHub上创建仓库，这一步会自动帮你创建）
7. 之后回到 GitHub 网页端的 Actions 页面，跟第四步一样操作

## 如果编译失败了怎么办

点进失败的那次运行记录，找到红色叉的那个步骤，点开会展开详细日志。把报错信息复制给我，我可以帮你定位是依赖版本问题还是代码问题。

常见的失败原因：
- `flutter pub get` 报错：通常是某个包版本和 Flutter 版本不兼容，需要调整 `pubspec.yaml` 里的版本号
- `flutter build windows` 报错：可能是某段代码在 Windows 平台下有问题（比如用了仅支持移动端的API）

## 之后想升级代码怎么办

每次改完代码，重新执行"第三步"把改动的文件上传覆盖（或者用 GitHub Desktop 提交+推送），Actions 会自动重新跑一遍编译，不需要重新配置。
