#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libavcodec/avcodec.h>
#include <libavutil/error.h>
#include <libavutil/frame.h>
#include <libavutil/opt.h>

#define TEST_WIDTH 1280
#define TEST_HEIGHT 720

struct codec_test {
	const char *label;
	const char *encoder;
};

static void print_av_error(const char *encoder, const char *operation, int error)
{
	char message[AV_ERROR_MAX_STRING_SIZE] = { 0 };
	av_strerror(error, message, sizeof(message));
	fprintf(stderr, "FAIL %s: %s: %s\n", encoder, operation, message);
}

static void fill_frame(AVFrame *frame)
{
	int y;

	for (y = 0; y < frame->height; y++)
		memset(frame->data[0] + y * frame->linesize[0], 16, frame->width);

	for (y = 0; y < frame->height / 2; y++) {
		memset(frame->data[1] + y * frame->linesize[1], 128, frame->width / 2);
		memset(frame->data[2] + y * frame->linesize[2], 128, frame->width / 2);
	}
}

static void set_low_latency_options(AVCodecContext *context, const char *encoder)
{
	if (strstr(encoder, "libx264") || strstr(encoder, "libx265")) {
		av_opt_set(context->priv_data, "preset", "ultrafast", 0);
		av_opt_set(context->priv_data, "tune", "zerolatency", 0);
	} else if (strstr(encoder, "libvpx")) {
		av_opt_set(context->priv_data, "deadline", "realtime", 0);
		av_opt_set(context->priv_data, "cpu-used", "8", 0);
		av_opt_set(context->priv_data, "lag-in-frames", "0", 0);
	}
}

static int run_test(const struct codec_test *test)
{
	const AVCodec *codec;
	AVCodecContext *context = NULL;
	AVFrame *frame = NULL;
	AVPacket *packet = NULL;
	int result = 1;
	int ret;

	codec = avcodec_find_encoder_by_name(test->encoder);
	if (!codec) {
		fprintf(stderr, "FAIL %s: encoder %s is unavailable\n", test->label,
			test->encoder);
		return 1;
	}

	context = avcodec_alloc_context3(codec);
	frame = av_frame_alloc();
	packet = av_packet_alloc();
	if (!context || !frame || !packet) {
		fprintf(stderr, "FAIL %s: allocation failed\n", test->label);
		goto out;
	}

	context->width = TEST_WIDTH;
	context->height = TEST_HEIGHT;
	context->time_base = (AVRational){ 1, 30 };
	context->framerate = (AVRational){ 30, 1 };
	context->pix_fmt = AV_PIX_FMT_YUV420P;
	context->bit_rate = 1000000;
	context->gop_size = 1;
	context->max_b_frames = 0;
	context->thread_count = 1;
	set_low_latency_options(context, test->encoder);

	ret = avcodec_open2(context, codec, NULL);
	if (ret < 0) {
		print_av_error(test->label, "avcodec_open2", ret);
		goto out;
	}

	frame->format = context->pix_fmt;
	frame->width = context->width;
	frame->height = context->height;
	frame->pts = 0;

	ret = av_frame_get_buffer(frame, 32);
	if (ret < 0) {
		print_av_error(test->label, "av_frame_get_buffer", ret);
		goto out;
	}

	ret = av_frame_make_writable(frame);
	if (ret < 0) {
		print_av_error(test->label, "av_frame_make_writable", ret);
		goto out;
	}
	fill_frame(frame);

	ret = avcodec_send_frame(context, frame);
	if (ret < 0) {
		print_av_error(test->label, "avcodec_send_frame", ret);
		goto out;
	}

	ret = avcodec_receive_packet(context, packet);
	if (ret == AVERROR(EAGAIN)) {
		ret = avcodec_send_frame(context, NULL);
		if (ret >= 0)
			ret = avcodec_receive_packet(context, packet);
	}
	if (ret < 0) {
		print_av_error(test->label, "avcodec_receive_packet", ret);
		goto out;
	}

	printf("OK %s encoder=%s bytes=%d resolution=%dx%d\n", test->label,
		test->encoder, packet->size, TEST_WIDTH, TEST_HEIGHT);
	result = 0;

out:
	av_packet_free(&packet);
	av_frame_free(&frame);
	avcodec_free_context(&context);
	return result;
}

int main(void)
{
	static const struct codec_test tests[] = {
		{ "H.264", "libx264" },
		{ "H.265", "libx265" },
		{ "VP8", "libvpx" },
		{ "VP9", "libvpx-vp9" },
	};
	size_t i;
	int failed = 0;

	for (i = 0; i < sizeof(tests) / sizeof(tests[0]); i++)
		failed += run_test(&tests[i]);

	if (failed) {
		fprintf(stderr, "CODEC_CHECK_FAILED count=%d\n", failed);
		return EXIT_FAILURE;
	}

	printf("CODEC_CHECK_OK codecs=4\n");
	return EXIT_SUCCESS;
}
