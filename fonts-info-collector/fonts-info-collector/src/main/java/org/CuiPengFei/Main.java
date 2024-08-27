package org.CuiPengFei;

import org.apache.fontbox.ttf.NameRecord;
import org.apache.fontbox.ttf.OTFParser;
import org.apache.fontbox.ttf.TTFParser;
import org.apache.fontbox.ttf.TrueTypeFont;
import org.apache.pdfbox.io.RandomAccessReadBufferedFile;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

import static java.lang.Runtime.getRuntime;
import static java.lang.System.out;
import static java.lang.Thread.currentThread;
import static java.util.Arrays.stream;
import static java.util.concurrent.Executors.newFixedThreadPool;

/**
 * 主类，负责扫描系统和用户字体目录，获取字体信息，并将信息保存到JSON文件中
 */
public class Main {

    // 系统字体目录环境变量获取
    private static final String SYSTEM_FONT_DIR = System.getenv("WINDIR") + "\\Fonts";
    // 用户字体目录属性获取
    private static final String USER_FONT_DIR = System.getProperty("user.home") + "\\AppData\\Local\\Microsoft\\Windows\\Fonts";
    // TTF和OTF解析器实例化
    private static final TTFParser TTF_PARSER = new TTFParser();
    private static final TTFParser OTF_PARSER = new OTFParser();
    // 版权提示关键词数组
    private static final String[] LICENSE_HINT = {"copyright", "trademark", "license", "microsoft"};

    /**
     * 程序入口方法
     *
     * @param args 命令行参数
     * @throws ExecutionException   执行异常
     * @throws InterruptedException 中断异常
     * @throws IOException          输入输出异常
     */
    public static void main(String[] args) throws ExecutionException, InterruptedException, IOException {
        ExecutorService executor = newFixedThreadPool(getRuntime().availableProcessors());
        try {
            // 列出所有字体文件
            List<File> fontFiles = listAllFonts();
            // 收集所有字体信息的未来对象
            List<Future<JSONObject>> futures = collectAllFontsInfo(fontFiles, executor);
            // 创建JSON数组并写入文件
            JSONArray fontsArray = createJson(futures);
            writeToFile(fontsArray);
        } finally {
            // 关闭线程池
            closeThreadPool(executor);
        }
    }

    /**
     * 将字体信息JSON数组写入文件
     *
     * @param fontsArray 字体信息JSON数组
     */
    private static void writeToFile(JSONArray fontsArray) {
        try (FileWriter file = new FileWriter("fonts_info.json")) {
            file.write(fontsArray.toString(4)); // 美化输出
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    /**
     * 从未来对象中创建JSON数组
     *
     * @param futures 未来对象列表
     * @return JSON数组，包含所有字体信息
     * @throws InterruptedException 中断异常
     * @throws ExecutionException   执行异常
     */
    private static JSONArray createJson(List<Future<JSONObject>> futures) throws InterruptedException, ExecutionException {
        JSONArray fontsArray = new JSONArray();
        for (Future<JSONObject> future : futures) {
            JSONObject fontInfo = future.get();
            if (fontInfo != null) {
                fontsArray.put(fontInfo);
            }
        }
        return fontsArray;
    }

    /**
     * 收集所有字体的信息
     *
     * @param fontFiles 字体文件列表
     * @param executor  线程池执行服务
     * @return 字体信息的未来对象列表
     */
    private static List<Future<JSONObject>> collectAllFontsInfo(List<File> fontFiles, ExecutorService executor) {
        List<Future<JSONObject>> futures = new ArrayList<>();
        for (File fontFile : fontFiles.stream().toList()) {
            Future<JSONObject> future = executor.submit(() -> collectFontInfo(fontFile));
            futures.add(future);
        }
        return futures;
    }

    /**
     * 列出所有字体文件
     *
     * @return 字体文件列表
     * @throws IOException 输入输出异常
     */
    private static List<File> listAllFonts() throws IOException {
        List<File> fontFiles = listFontFiles(Paths.get(SYSTEM_FONT_DIR));
        fontFiles.addAll(listFontFiles(Paths.get(USER_FONT_DIR)));
        return fontFiles;
    }

    /**
     * 收集单个字体文件的信息
     *
     * @param fontFile 字体文件
     * @return 包含字体信息的JSON对象
     */
    private static JSONObject collectFontInfo(File fontFile) {
        TTFParser parser = TTF_PARSER;
        if (fontFile.getName().toLowerCase().contains(".otf")) {
            parser = OTF_PARSER;
        }

        try (TrueTypeFont ttf = parser.parse(new RandomAccessReadBufferedFile(fontFile))) {
            JSONObject fontInfo = new JSONObject();

            List<NameRecord> nameRecords = ttf.getNaming().getNameRecords();
            String fontName = nameRecords.get(NameRecord.NAME_FULL_FONT_NAME).getString();
            Set<String> licenseInfo = nameRecords.stream()
                    .map(NameRecord::getString)
                    .filter(string -> stream(LICENSE_HINT).anyMatch(hint -> string.toLowerCase().contains(hint)))
                    .collect(Collectors.toSet());

            out.println(currentThread().getName() + " Font Name: " + fontName);

            fontInfo.put("fontName", fontName);
            fontInfo.put("licenseInfo", new JSONArray(licenseInfo));
            return fontInfo;
        } catch (IOException e) {
            System.err.println("Failed to read font file: " + fontFile.getName());
            e.printStackTrace();
        }

        return null;
    }

    /**
     * 列出指定目录下的所有字体文件
     *
     * @param directory 目录路径
     * @return 字体文件列表
     * @throws IOException 输入输出异常
     */
    private static List<File> listFontFiles(Path directory) throws IOException {
        List<File> fontFiles = new ArrayList<>();

        try (DirectoryStream<Path> stream = Files.newDirectoryStream(directory, file -> {
            String fileName = file.getFileName().toString().toLowerCase();
            return fileName.endsWith(".ttf") || fileName.endsWith(".otf");
        })) {
            for (Path entry : stream) {
                fontFiles.add(entry.toFile());
            }
        }
        return fontFiles;
    }

    /**
     * 关闭线程池
     *
     * @param executor 线程池执行服务
     */
    private static void closeThreadPool(ExecutorService executor) {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(60, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            currentThread().interrupt();
        }
    }
}
