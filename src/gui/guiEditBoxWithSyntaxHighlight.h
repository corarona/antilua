#pragma once

#include "guiEditBoxWithScrollbar.h"
#include "SColor.h"
#include <vector>
#include <unordered_set>

struct SyntaxHighlightColors {
	video::SColor keyword    {0xFF569cd6};
	video::SColor string     {0xFFce9178};
	video::SColor comment    {0xFF6a9955};
	video::SColor number     {0xFFb5cea8};
	video::SColor builtin    {0xFFc586c0};
	video::SColor identifier {0xFFdcdcaa};
	video::SColor op         {0xFFd4d4d4};
	video::SColor punct      {0xFFd4d4d4};
	video::SColor text       {0xFFd4d4d4};

	static SyntaxHighlightColors fromOptionString(const std::string &opts);
};

class GUIEditBoxWithSyntaxHighlight : public GUIEditBoxWithScrollBar
{
public:
	GUIEditBoxWithSyntaxHighlight(const wchar_t *text, bool border,
		gui::IGUIEnvironment *environment, IGUIElement *parent, s32 id,
		const core::rect<s32> &rectangle, ISimpleTextureSource *tsrc,
		bool writable, const SyntaxHighlightColors &colors);

	void draw() override;
	bool OnEvent(const SEvent &event) override;
	void setText(const wchar_t *text) override;

	void calculateScrollPos();

private:
	enum TokenType {
		T_KEYWORD, T_STRING, T_COMMENT, T_NUMBER, T_BUILTIN,
		T_IDENTIFIER, T_OPERATOR, T_PUNCTUATION, T_WHITESPACE,
		T_NUM_TYPES
	};

	struct Token {
		TokenType type;
		size_t start;
		size_t length;
	};

	void tokenizeAll();
	TokenType classifyWord(const std::wstring &word) const;
	video::SColor colorForToken(TokenType type) const;

	SyntaxHighlightColors m_colors;
	std::vector<std::vector<Token>> m_line_tokens;
	u32 m_tokenized_text_size = 0;

	static const std::unordered_set<std::wstring> s_keywords;
	static const std::unordered_set<std::wstring> s_builtins;
};
